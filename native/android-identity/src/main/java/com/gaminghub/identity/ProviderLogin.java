package com.gaminghub.identity;

import android.app.Activity;
import android.content.Intent;
import android.content.MutableContextWrapper;
import android.os.CancellationSignal;
import androidx.credentials.*;
import androidx.credentials.exceptions.*;
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;
import com.facebook.*;
import com.facebook.login.*;
import java.util.Collections;
import java.util.concurrent.Executor;

/** Native provider UI is requested explicitly. Tokens are returned in memory only. */
final class ProviderLogin {
    interface Result { void complete(String provider,String token,String error); }
    private final Activity activity;
    private final Result callback;
    private CallbackManager facebookCallbacks;
    private CancellationSignal cancellation;
    private final Executor executor;
    private String pending="";
    ProviderLogin(Activity activity,Result callback) {
        this.activity=activity;this.callback=callback;this.executor=activity::runOnUiThread;
    }
    private void finish(String provider,String token,String error) {
        if (!provider.equals(pending)) return;
        pending="";cancellation=null;
        callback.complete(provider,token,error);
    }
    void google(String webClientId,String nonce) {
        if (!pending.isEmpty()) { callback.complete("google","","busy");return; }
        pending="google";
        activity.runOnUiThread(()->{
            try {
                cancellation=new CancellationSignal();
                GetSignInWithGoogleOption option=new GetSignInWithGoogleOption.Builder(webClientId).setNonce(nonce).build();
                GetCredentialRequest request=new GetCredentialRequest.Builder().addCredentialOption(option).build();
                CredentialManager.create(activity).getCredentialAsync(new MutableContextWrapper(activity),request,cancellation,executor,
                    new CredentialManagerCallback<GetCredentialResponse,GetCredentialException>() {
                        @Override public void onResult(GetCredentialResponse response) {
                            try {
                                Credential credential=response.getCredential();
                                if (!(credential instanceof CustomCredential) ||
                                    !GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.equals(credential.getType())) {
                                    finish("google","","invalid_credential");return;
                                }
                                finish("google",GoogleIdTokenCredential.createFrom(credential.getData()).getIdToken(),"");
                            } catch (Exception ignored) { finish("google","","invalid_credential"); }
                        }
                        @Override public void onError(GetCredentialException error) {
                            finish("google","",error instanceof GetCredentialCancellationException?"cancelled":"provider_unavailable");
                        }
                    });
            } catch (Exception ignored) { finish("google","","provider_unavailable"); }
        });
    }
    @SuppressWarnings("deprecation") void facebook(String appId,String clientToken) {
        if (!pending.isEmpty()) { callback.complete("facebook","","busy");return; }
        pending="facebook";
        activity.runOnUiThread(()->{
            try {
                FacebookSdk.setAutoLogAppEventsEnabled(false);
                FacebookSdk.setAdvertiserIDCollectionEnabled(false);
                FacebookSdk.setAutoInitEnabled(false);
                FacebookSdk.setApplicationId(appId);
                FacebookSdk.setClientToken(clientToken);
                FacebookSdk.sdkInitialize(activity.getApplicationContext());
                facebookCallbacks=CallbackManager.Factory.create();
                LoginManager.getInstance().registerCallback(facebookCallbacks,new FacebookCallback<LoginResult>() {
                    @Override public void onSuccess(LoginResult result) {
                        String token=result.getAccessToken().getToken();
                        // Discard Facebook SDK's local cache; only our Keystore refresh credential persists.
                        LoginManager.getInstance().logOut();
                        finish("facebook",token,"");
                    }
                    @Override public void onCancel() { finish("facebook","","cancelled"); }
                    @Override public void onError(FacebookException error) { finish("facebook","","provider_unavailable"); }
                });
                // public_profile only: an email is not needed to establish a stable provider identity.
                LoginManager.getInstance().logInWithReadPermissions(activity,Collections.singletonList("public_profile"));
            } catch (Exception ignored) { finish("facebook","","provider_unavailable"); }
        });
    }
    void activityResult(int request,int result,Intent data) {
        if (facebookCallbacks!=null) facebookCallbacks.onActivityResult(request,result,data);
    }
    void signOut() {
        activity.runOnUiThread(()->{
            if (cancellation!=null) cancellation.cancel();
            pending="";
            if (FacebookSdk.isInitialized()) LoginManager.getInstance().logOut();
            CredentialManager.create(activity).clearCredentialStateAsync(new ClearCredentialStateRequest(),null,executor,
                new CredentialManagerCallback<Void,ClearCredentialException>() {
                    @Override public void onResult(Void ignored) {}
                    @Override public void onError(ClearCredentialException ignored) {}
                });
        });
    }
}
