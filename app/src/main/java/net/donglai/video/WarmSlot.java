package net.donglai.video;

import android.content.Context;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.SystemClock;
import android.util.Log;

/** Owns at most one silent, asynchronously prepared next item. Main-thread only. */
final class WarmSlot {
 private final Context context; private MediaPlayer player; private String id=""; private boolean ready; private int sequence; private long started;
 WarmSlot(Context context){this.context=context.getApplicationContext();}
 void prepare(String nextId,String url,int position){if(nextId.equals(id)&&player!=null)return;clear();final int token=++sequence;id=nextId;started=SystemClock.elapsedRealtime();try{MediaPlayer candidate=new MediaPlayer();player=candidate;candidate.setAudioAttributes(WarmVideoView.attributes());candidate.setVolume(0,0);candidate.setDataSource(context,Uri.parse(url));candidate.setOnErrorListener((p,w,e)->{if(token==sequence)clear();return true;});candidate.setOnPreparedListener(p->{if(token!=sequence||p!=player)return;if(position>0&&p.getDuration()>position+2000){p.setOnSeekCompleteListener(q->{if(token==sequence&&q==player){ready=true;Log.i("DonglaiTiming","预加载就绪 "+(SystemClock.elapsedRealtime()-started)+"ms");}});p.seekTo(position);}else{ready=true;Log.i("DonglaiTiming","预加载就绪 "+(SystemClock.elapsedRealtime()-started)+"ms");}});candidate.prepareAsync();}catch(Exception e){clear();}}
 MediaPlayer take(String requested){if(!ready||player==null||!requested.equals(id))return null;MediaPlayer result=player;player=null;id="";ready=false;sequence++;result.setOnPreparedListener(null);result.setOnSeekCompleteListener(null);result.setOnErrorListener(null);result.setVolume(1,1);return result;}
 void clear(){sequence++;ready=false;id="";if(player!=null){try{player.release();}catch(Exception ignored){}player=null;}}
}
