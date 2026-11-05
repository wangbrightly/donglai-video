import Foundation
import AVFoundation
import AppKit

let id = "c88c163b-b1db-4510-833c-61494d6bd350"
let detail = URL(string: "https://baike.azpdl.net/selectWikiPageById_WikiPageAction.pdl!?cid=\(id)")!
let deadline = Date().addingTimeInterval(35)
var finished = false
var succeeded = false
URLSession.shared.dataTask(with: detail) { data, _, error in
    guard let data, error == nil,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let vo = object["vo"] as? [String: Any], let html = vo["content"] as? String,
          let regex = try? NSRegularExpression(pattern: "(?:data-url|src)=[\\\"'](https?://[^\\\"']+\\.m3u8[^\\\"']*)[\\\"']", options: .caseInsensitive),
          let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let range = Range(match.range(at: 1), in: html) else { print("FAIL: detail or HLS parse"); finished = true; return }
    var address = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
    if address.lowercased().hasPrefix("http://") { address = "https://" + address.dropFirst(7) }
    guard let url = URL(string: address) else { print("FAIL: invalid HLS URL"); finished = true; return }
    DispatchQueue.main.async {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.play()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let time = player.currentTime().seconds
            if item.status == .failed { print("FAIL: \(item.error?.localizedDescription ?? "player error")"); timer.invalidate(); finished = true }
            else if time.isFinite && time > 1 { print("PASS: AVPlayer played \(String(format: "%.1f", time)) seconds"); timer.invalidate(); player.pause(); succeeded = true; finished = true }
        }
    }
}.resume()
while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
if !finished { print("FAIL: playback timed out") }
exit(succeeded ? 0 : 1)
