package com.gaminghub.identity;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.util.Base64;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/** System photo selection; no broad storage permission or persistent URI grant. */
final class AvatarPicker {
    static final int REQUEST=27461;
    interface Result { void complete(String image,String error); }
    private final Activity activity;
    private final Result result;
    private boolean busy;
    AvatarPicker(Activity activity,Result result) { this.activity=activity;this.result=result; }
    void open() {
        activity.runOnUiThread(()-> {
            if(busy)return;
            busy=true;
            Intent pick=new Intent(Intent.ACTION_OPEN_DOCUMENT);
            pick.addCategory(Intent.CATEGORY_OPENABLE);pick.setType("image/*");
            try { activity.startActivityForResult(pick,REQUEST); }
            catch(Exception ignored) { finish("","unavailable"); }
        });
    }
    boolean activityResult(int request,int status,Intent data) {
        if(request!=REQUEST)return false;
        if(status!=Activity.RESULT_OK || data==null || data.getData()==null) {
            finish("","cancelled");return true;
        }
        new Thread(()-> {
            try(InputStream input=activity.getContentResolver().openInputStream(data.getData())) {
                ByteArrayOutputStream raw=new ByteArrayOutputStream();byte[] chunk=new byte[32768];int count;
                while((count=input.read(chunk))!=-1) {
                    if(raw.size()+count>16*1024*1024)throw new IllegalArgumentException();
                    raw.write(chunk,0,count);
                }
                byte[] bytes=raw.toByteArray();BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;
                BitmapFactory.decodeByteArray(bytes,0,bytes.length,bounds);
                if(bounds.outWidth<16 || bounds.outHeight<16 || (long)bounds.outWidth*bounds.outHeight>64000000)throw new IllegalArgumentException();
                BitmapFactory.Options options=new BitmapFactory.Options();options.inSampleSize=1;
                while(Math.max(bounds.outWidth,bounds.outHeight)/options.inSampleSize>1024)options.inSampleSize*=2;
                Bitmap image=BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);
                if(image==null)throw new IllegalArgumentException();
                Matrix matrix=new Matrix();
                try {
                    int orientation=new ExifInterface(new ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION,1);
                    if(orientation==3)matrix.postRotate(180);if(orientation==6)matrix.postRotate(90);if(orientation==8)matrix.postRotate(270);
                    if(orientation==2)matrix.postScale(-1,1);if(orientation==4)matrix.postScale(1,-1);
                    if(orientation==5){matrix.postRotate(90);matrix.postScale(-1,1);}
                    if(orientation==7){matrix.postRotate(270);matrix.postScale(-1,1);}
                } catch(Exception ignored) { }
                Bitmap rotated=Bitmap.createBitmap(image,0,0,image.getWidth(),image.getHeight(),matrix,true);
                int edge=Math.min(rotated.getWidth(),rotated.getHeight());
                Bitmap square=Bitmap.createBitmap(rotated,(rotated.getWidth()-edge)/2,(rotated.getHeight()-edge)/2,edge,edge);
                Bitmap avatar=Bitmap.createScaledBitmap(square,256,256,true);
                ByteArrayOutputStream output=new ByteArrayOutputStream();avatar.compress(Bitmap.CompressFormat.JPEG,85,output);
                if(avatar!=square)avatar.recycle();if(square!=rotated)square.recycle();if(rotated!=image)rotated.recycle();image.recycle();
                finish(Base64.encodeToString(output.toByteArray(),Base64.NO_WRAP),"");
            } catch(Exception | OutOfMemoryError ignored) { finish("","invalid_image"); }
        },"GamingHubAvatar").start();
        return true;
    }
    private void finish(String image,String error) {
        activity.runOnUiThread(()->{busy=false;result.complete(image,error);});
    }
}
