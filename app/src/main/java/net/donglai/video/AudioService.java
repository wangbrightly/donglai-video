package net.donglai.video;

import android.app.*;
import android.content.*;
import android.media.*;
import android.os.*;

public final class AudioService extends Service {
 static AudioService instance; private static final String CHANNEL="playback"; private MediaPlayer player; private String id=""; private int startPosition; private boolean ready; private final Handler handler=new Handler(); private AudioManager audio; private AudioFocusRequest focus;
 private final Runnable saver=new Runnable(){public void run(){save();handler.postDelayed(this,5000);}};
 @Override public void onCreate(){super.onCreate();instance=this;getSystemService(NotificationManager.class).createNotificationChannel(new NotificationChannel(CHANNEL,"后台播放",NotificationManager.IMPORTANCE_LOW));audio=(AudioManager)getSystemService(AUDIO_SERVICE);}
 @Override public int onStartCommand(Intent intent,int flags,int startId){
  if(intent==null||"stop".equals(intent.getAction())){stopSelf();return START_NOT_STICKY;}
  id=intent.getStringExtra("id");String url=intent.getStringExtra("url"),title=intent.getStringExtra("title");startPosition=intent.getIntExtra("position",0);float speed=intent.getFloatExtra("speed",1f);
  if(id==null||url==null){stopSelf();return START_NOT_STICKY;}
  Intent launch=new Intent(this,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP|Intent.FLAG_ACTIVITY_CLEAR_TOP);PendingIntent content=PendingIntent.getActivity(this,0,launch,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
  PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,AudioService.class).setAction("stop"),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
  Notification notification=new Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_media_play).setContentTitle(title==null?"东来讲堂":title).setContentText("后台播放中").setContentIntent(content).setOngoing(true).addAction(new Notification.Action.Builder(null,"停止",stop).build()).build();startForeground(1,notification);
  AudioAttributes attrs=new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build();focus=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attrs).setOnAudioFocusChangeListener(change->{if(change<=AudioManager.AUDIOFOCUS_LOSS_TRANSIENT){save();stopSelf();}}).build();
  if(audio.requestAudioFocus(focus)!=AudioManager.AUDIOFOCUS_REQUEST_GRANTED){stopSelf();return START_NOT_STICKY;}
  try{player=new MediaPlayer();player.setAudioAttributes(attrs);player.setWakeMode(getApplicationContext(),PowerManager.PARTIAL_WAKE_LOCK);player.setDataSource(url);player.setOnPreparedListener(mp->{ready=true;if(startPosition>0)mp.seekTo(startPosition);mp.start();try{mp.setPlaybackParams(mp.getPlaybackParams().setSpeed(speed));}catch(Exception ignored){}handler.postDelayed(saver,5000);});player.setOnCompletionListener(mp->{getSharedPreferences("MainActivity",MODE_PRIVATE).edit().putInt("position_"+id,0).apply();ready=false;stopSelf();});player.setOnErrorListener((mp,what,extra)->{stopSelf();return true;});player.prepareAsync();}catch(Exception e){stopSelf();}
  return START_NOT_STICKY;
 }
 private void save(){if(ready&&player!=null&&!id.isEmpty()){try{getSharedPreferences("MainActivity",MODE_PRIVATE).edit().putInt("position_"+id,player.getCurrentPosition()).commit();}catch(IllegalStateException ignored){}}}
 String videoId(){return id;}
 int handBack(){int position=startPosition;if(ready&&player!=null){try{position=player.getCurrentPosition();player.pause();}catch(IllegalStateException ignored){}}getSharedPreferences("MainActivity",MODE_PRIVATE).edit().putInt("position_"+id,position).commit();ready=false;return position;}
 @Override public void onDestroy(){instance=null;handler.removeCallbacksAndMessages(null);save();if(player!=null){player.release();player=null;}if(focus!=null)audio.abandonAudioFocusRequest(focus);super.onDestroy();}
 @Override public IBinder onBind(Intent i){return null;}
}
