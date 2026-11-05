package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class VideoUrlTest {
 @Test public void acceptsHttpAndHttpsVideoAddresses(){
  assertEquals("https://example.com/a.m3u8", VideoUrl.fromHtml("<img data-url=\"http://example.com/a.m3u8\">"));
  assertEquals("https://example.com/b.m3u8?x=1&y=2", VideoUrl.fromHtml("<video src='https://example.com/b.m3u8?x=1&amp;y=2'>"));
  assertNull(VideoUrl.fromHtml("<p>no video</p>"));
 }
}
