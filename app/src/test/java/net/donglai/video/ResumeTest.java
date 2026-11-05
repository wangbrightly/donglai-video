package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class ResumeTest {
 @Test public void resumesUnlessAtEndOrInvalid(){
  assertEquals(60000, Resume.position(60000,120000));
  assertEquals(0, Resume.position(119000,120000));
  assertEquals(0, Resume.position(-1,120000));
  assertEquals(60000, Resume.position(60000,0));
 }
}
