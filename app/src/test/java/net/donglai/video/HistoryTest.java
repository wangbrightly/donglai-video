package net.donglai.video;
import org.junit.Test;
import static org.junit.Assert.*;
public class HistoryTest {
 @Test public void movesRewatchedVideoToFrontWithoutDuplicates(){
  assertEquals("c,a,b",History.record("a,b,c","c"));
  assertEquals("d,a,b",History.record("a,b","d"));
  assertEquals("a",History.record("","a"));
 }
 @Test public void removeOnlyTheSelectedRecord(){
  assertEquals("a,c",History.remove("a,b,c","b"));
  assertEquals("",History.remove("a","a"));
 }
 @Test public void navigationWrapsAtBothEnds(){
  assertEquals(4,History.move(0,-1,5));
  assertEquals(0,History.move(4,1,5));
  assertEquals(2,History.move(3,-1,5));
 }
}
