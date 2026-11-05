package com.gaminghub.identity;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.godot.plugin.SignalInfo;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Keystore key is non-exportable. Only encrypted refresh credentials reach disk. */
public final class GamingHubIdentityPlugin extends GodotPlugin {
    private static final String ALIAS = "gaminghub.identity.session.v1";
    private ProviderLogin providers;
    public GamingHubIdentityPlugin(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "GamingHubIdentity"; }
    @Override public java.util.Set<SignalInfo> getPluginSignals() {
        return java.util.Collections.singleton(new SignalInfo("social_result",String.class,String.class,String.class));
    }
    private ProviderLogin providers() {
        if (providers==null) providers=new ProviderLogin(getActivity(),(provider,token,error)->emitSignal("social_result",provider,token,error));
        return providers;
    }
    @UsedByGodot public void requestGoogleLogin(String clientId,String nonce) { providers().google(clientId,nonce); }
    @UsedByGodot public void requestFacebookLogin(String appId,String clientToken) { providers().facebook(appId,clientToken); }
    @UsedByGodot public void providerSignOut() { if (getActivity()!=null) providers().signOut(); }
    /** User-triggered Android share sheet; no contacts access or automatic sending. */
    @UsedByGodot public void shareRoomCode(String code,String language) {
        if (getActivity()==null || code==null || !code.matches("[0-9]{6}")) return;
        getActivity().runOnUiThread(()-> {
            android.content.Intent message=new android.content.Intent(android.content.Intent.ACTION_SEND);
            message.setType("text/plain");
            message.putExtra(android.content.Intent.EXTRA_TEXT,
                ("ar".equals(language)?"انضم إلى غرفتي في Gaming Hub بالكود: ":"Join my Gaming Hub room with code: ")+code);
            try {
                getActivity().startActivity(android.content.Intent.createChooser(message,
                    "ar".equals(language)?"مشاركة دعوة اللعب":"Share game invitation"));
            } catch (android.content.ActivityNotFoundException ignored) { }
        });
    }
    @Override public void onMainActivityResult(int requestCode,int resultCode,android.content.Intent data) {
        if (providers!=null) providers.activityResult(requestCode,resultCode,data);
    }
    private SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        SecretKey existing = (SecretKey)store.getKey(ALIAS, null);
        if (existing != null) return existing;
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    private AtomicFile file() {
        if (getActivity()==null) throw new IllegalStateException("No activity");
        return new AtomicFile(new File(getActivity().getNoBackupFilesDir(),"identity_session.v1"));
    }
    @UsedByGodot public synchronized boolean storeSession(String value) {
        if (value.length()>4096) return false;
        try {
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE,key());
            cipher.updateAAD(ALIAS.getBytes(StandardCharsets.UTF_8));
            byte[] encrypted=cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
            AtomicFile target=file();
            FileOutputStream output=null;
            try {
                output=target.startWrite();
                output.write(cipher.getIV()); output.write(encrypted);
                target.finishWrite(output);
            } catch (Exception failure) { target.failWrite(output); throw failure; }
            return true;
        } catch (Exception ignored) { return false; }
    }
    @UsedByGodot public synchronized String loadSession() {
        try {
            AtomicFile target=file();
            if (!target.getBaseFile().exists() || target.getBaseFile().length()>8192) return "";
            byte[] encrypted=target.readFully();
            if (encrypted.length<29) return "";
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Arrays.copyOfRange(encrypted,0,12)));
            cipher.updateAAD(ALIAS.getBytes(StandardCharsets.UTF_8));
            return new String(cipher.doFinal(Arrays.copyOfRange(encrypted,12,encrypted.length)),StandardCharsets.UTF_8);
        } catch (Exception ignored) { return ""; }
    }
    @UsedByGodot public synchronized boolean clearSession() {
        try { file().delete(); return true; } catch (Exception ignored) { return false; }
    }
    /** Debug acceptance probe uses a separate file; never reads/writes a real session. */
    @UsedByGodot public synchronized boolean storageProbe(String mode) {
        if (getActivity()==null || (getActivity().getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)==0) return false;
        try {
            AtomicFile target=new AtomicFile(new File(getActivity().getNoBackupFilesDir(),"identity_probe.v1"));
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
            byte[] expected="GamingHub non-secret persistence probe".getBytes(StandardCharsets.UTF_8);
            if ("write".equals(mode)) {
                cipher.init(Cipher.ENCRYPT_MODE,key());
                cipher.updateAAD(ALIAS.getBytes(StandardCharsets.UTF_8));
                FileOutputStream output=null;
                try {
                    output=target.startWrite();output.write(cipher.getIV());output.write(cipher.doFinal(expected));target.finishWrite(output);
                } catch (Exception failure) { target.failWrite(output); throw failure; }
                return true;
            }
            if (!"read".equals(mode)) return false;
            byte[] encrypted=target.readFully();
            cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Arrays.copyOfRange(encrypted,0,12)));
            cipher.updateAAD(ALIAS.getBytes(StandardCharsets.UTF_8));
            return Arrays.equals(expected,cipher.doFinal(Arrays.copyOfRange(encrypted,12,encrypted.length)));
        } catch (Exception ignored) { return false; }
    }
}
