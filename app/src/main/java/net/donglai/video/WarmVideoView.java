package net.donglai.video;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;

/** Surface-backed player that can take ownership of an already prepared player. */
final class WarmVideoView extends SurfaceView implements SurfaceHolder.Callback {
 private MediaPlayer mp; private boolean ready, playWhenReady; private float desiredSpeed=1f; private int videoWidth,videoHeight;
 private MediaPlayer.OnPreparedListener onPrepared; private MediaPlayer.OnCompletionListener onCompletion; private MediaPlayer.OnErrorListener onError;
 private final AudioManager audio; private final AudioFocusRequest focus;
 WarmVideoView(Context context){super(context);getHolder().addCallback(this);audio=(AudioManager)context.getSystemService(Context.AUDIO_SERVICE);AudioAttributes attrs=attributes();focus=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attrs).setOnAudioFocusChangeListener(change->{if(change==AudioManager.AUDIOFOCUS_LOSS||change==AudioManager.AUDIOFOCUS_LOSS_TRANSIENT){pause();}}).build();}
 static AudioAttributes attributes(){return new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build();}
 void setOnPreparedListener(MediaPlayer.OnPreparedListener listener){onPrepared=listener;}
 void setOnCompletionListener(MediaPlayer.OnCompletionListener listener){onCompletion=listener;}
 void setOnErrorListener(MediaPlayer.OnErrorListener listener){onError=listener;}
 void setVideoURI(Uri uri){stopPlayback();try{MediaPlayer candidate=new MediaPlayer();mp=candidate;candidate.setAudioAttributes(attributes());attach(candidate);candidate.setDataSource(getContext(),uri);candidate.setOnPreparedListener(p->finishPrepared(p));candidate.prepareAsync();}catch(Exception e){releasePlayer();if(onError!=null)onError.onError(null,MediaPlayer.MEDIA_ERROR_UNKNOWN,0);}}
 void adopt(MediaPlayer candidate){stopPlayback();mp=candidate;attach(candidate);finishPrepared(candidate);}
 private void attach(MediaPlayer candidate){if(getHolder().getSurface().isValid())candidate.setDisplay(getHolder());candidate.setOnVideoSizeChangedListener((p,w,h)->{if(p==mp){videoWidth=w;videoHeight=h;requestLayout();}});candidate.setOnCompletionListener(p->{playWhenReady=false;if(onCompletion!=null)onCompletion.onCompletion(p);});candidate.setOnErrorListener((p,w,e)->{if(p!=mp)return true;ready=false;playWhenReady=false;return onError!=null&&onError.onError(p,w,e);});}
 private void finishPrepared(MediaPlayer p){if(p!=mp)return;ready=true;videoWidth=p.getVideoWidth();videoHeight=p.getVideoHeight();requestLayout();if(onPrepared!=null)onPrepared.onPrepared(p);if(playWhenReady&&getHolder().getSurface().isValid()&&!isPlaying())start();}
 void start(){playWhenReady=true;if(!ready||mp==null||!getHolder().getSurface().isValid())return;try{if(audio.requestAudioFocus(focus)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED){mp.start();try{mp.setPlaybackParams(mp.getPlaybackParams().setSpeed(desiredSpeed));}catch(IllegalArgumentException ignored){}}}catch(IllegalStateException ignored){}}
 void pause(){playWhenReady=false;if(ready&&mp!=null)try{if(mp.isPlaying())mp.pause();}catch(IllegalStateException ignored){} audio.abandonAudioFocusRequest(focus);}
 void setSpeed(float speed){desiredSpeed=speed;if(isPlaying())try{mp.setPlaybackParams(mp.getPlaybackParams().setSpeed(speed));}catch(IllegalArgumentException|IllegalStateException ignored){}}
 boolean isPlaying(){if(!ready||mp==null)return false;try{return mp.isPlaying();}catch(IllegalStateException e){return false;}}
 int getDuration(){if(!ready||mp==null)return -1;try{return mp.getDuration();}catch(IllegalStateException e){return -1;}}
 int getCurrentPosition(){if(!ready||mp==null)return 0;try{return mp.getCurrentPosition();}catch(IllegalStateException e){return 0;}}
 void seekTo(int position){if(ready&&mp!=null)try{mp.seekTo(position);}catch(IllegalStateException ignored){}}
 void stopPlayback(){playWhenReady=false;releasePlayer();audio.abandonAudioFocusRequest(focus);videoWidth=videoHeight=0;requestLayout();}
 private void releasePlayer(){ready=false;if(mp!=null){try{mp.release();}catch(Exception ignored){}mp=null;}}
 @Override public void surfaceCreated(SurfaceHolder holder){if(mp!=null){mp.setDisplay(holder);if(playWhenReady)start();}}
 @Override public void surfaceChanged(SurfaceHolder holder,int format,int width,int height){}
 @Override public void surfaceDestroyed(SurfaceHolder holder){if(mp!=null)try{mp.setDisplay(null);}catch(IllegalStateException ignored){}}
 @Override protected void onMeasure(int widthSpec,int heightSpec){int w=View.getDefaultSize(videoWidth,widthSpec),h=View.getDefaultSize(videoHeight,heightSpec);if(videoWidth>0&&videoHeight>0&&w>0&&h>0){if((long)videoWidth*h>(long)w*videoHeight)h=(int)((long)w*videoHeight/videoWidth);else w=(int)((long)h*videoWidth/videoHeight);}setMeasuredDimension(w,h);}
}
