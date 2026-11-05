package net.donglai.video;
import java.util.regex.*;
final class VideoUrl {
 static String fromHtml(String html){
  Matcher m=Pattern.compile("(?:data-url|src)=[\\\"'](https?://[^\\\"']+\\.m3u8[^\\\"']*)[\\\"']",Pattern.CASE_INSENSITIVE).matcher(html);
  if(!m.find())return null;
  String url=m.group(1).replace("&amp;","&");
  return url.regionMatches(true,0,"http://",0,7)?"https://"+url.substring(7):url;
 }
}
