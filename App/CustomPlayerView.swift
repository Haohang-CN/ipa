import SwiftUI
import AVKit

// Keep one AVPlayer throughout inline, full-screen, and picture-in-picture playback.
final class VideoLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor final class PictureWindow: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    private var controller: AVPictureInPictureController?
    var onActiveChanged: ((Bool) -> Void)?
    func attach(_ layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              controller?.isPictureInPictureActive != true else { return }
        controller = AVPictureInPictureController(playerLayer: layer)
        controller?.delegate = self
    }
    func toggle() {
        guard let controller, controller.isPictureInPicturePossible || controller.isPictureInPictureActive else { return }
        if controller.isPictureInPictureActive { controller.stopPictureInPicture() }
        else { onActiveChanged?(true); controller.startPictureInPicture() }
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { onActiveChanged?(false) }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) { onActiveChanged?(false) }
}

@MainActor struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    let pictureWindow: PictureWindow
    func makeUIView(context: Context) -> VideoLayerView {
        let view = VideoLayerView()
        view.backgroundColor = .black
        view.videoLayer.videoGravity = .resizeAspect
        view.videoLayer.player = player
        pictureWindow.attach(view.videoLayer)
        return view
    }
    func updateUIView(_ view: VideoLayerView, context: Context) {
        if view.videoLayer.player !== player { view.videoLayer.player = player }
    }
}

@MainActor struct CustomPlayerView: View {
    @ObservedObject var model: PlayerModel
    let fullscreen: Bool
    let title: String
    let onFullscreen: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onEpisodes: () -> Void
    let onDownload: () -> Void
    let onSkipSettings: () -> Void
    @StateObject private var pictureWindow = PictureWindow()
    @State private var controlsVisible = true
    @State private var seekPreview: Double?
    @State private var seekingSlider = false
    @State private var gestureKind = 0 // 1: seek, 2: brightness, 3: app volume
    @State private var dragStart = 0.0
    @State private var feedback = ""
    @State private var hideTask: Task<Void,Never>?
    @State private var holding = false
    @State private var speedBeforeHold: Float = 1
    private let accent = Color.yellow

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                PlayerSurface(player:model.player,pictureWindow:pictureWindow)
                LinearGradient(colors:[.black.opacity(0.28),.clear,.clear,.black.opacity(0.35)],startPoint:.top,endPoint:.bottom).allowsHitTesting(false)
                Color.clear.contentShape(Rectangle())
                    .gesture(TapGesture(count:2).onEnded { let paused = model.playing; model.toggle(); signal(paused ? "已暂停" : "继续播放") }
                        .exclusively(before: TapGesture().onEnded { reveal() }))
                    .simultaneousGesture(DragGesture(minimumDistance:18)
                        .onChanged { value in updateDrag(value,size:geometry.size) }
                        .onEnded { value in endDrag(value,size:geometry.size) })
                    .onLongPressGesture(minimumDuration:0.7,maximumDistance:10,pressing: { pressed in
                        if !pressed && holding {
                            holding = false
                            if model.playing { model.player.rate = speedBeforeHold }
                            feedback = ""
                        }
                    },perform: {
                        guard !holding && model.playing else { return }
                        holding = true; speedBeforeHold = model.preferredRate
                        if model.playing { model.player.rate = 2 }
                        signal("2× 快速播放")
                    })
                if !feedback.isEmpty {
                    Text(feedback).font(.callout.weight(.semibold))
                        .padding(.horizontal,18).padding(.vertical,10)
                        .background(.black.opacity(0.65),in:Capsule())
                        .allowsHitTesting(false)
                }
                if controlsVisible {
                    VStack(spacing:0) {
                        HStack(alignment:.top,spacing:8) {
                            if fullscreen { control("chevron.left",label:"返回") { onFullscreen() } }
                            Text(title).font(.callout.weight(.semibold)).lineLimit(1)
                                .padding(.horizontal,10).padding(.vertical,8)
                                .background(.black.opacity(0.35),in:Capsule())
                            Spacer(minLength:0)
                            Menu {
                                ForEach([0.75,1,1.25,1.5,2],id:\.self) { rate in
                                    Button(String(format:"%.2g×",rate)) { model.setRate(Float(rate)); reveal() }
                                }
                                Button("片头片尾") { onSkipSettings() }
                                Button("下载本集") { onDownload() }
                            } label: { Image(systemName:"gearshape.fill").font(.callout.weight(.semibold)).frame(width:38,height:38).background(.black.opacity(0.42),in:Circle()) }
                                .accessibilityLabel("播放设置")
                            control("backward.end.fill",label:"上一集") { onPrevious() }
                            control("forward.end.fill",label:"下一集") { onNext() }
                        }
                        Spacer(minLength:10)
                        HStack(alignment:.bottom,spacing:8) {
                            control("gobackward",label:"后退17秒",text:"−17") { model.jump(-17); reveal() }
                            Spacer()
                            if fullscreen { control("list.bullet",label:"选集") { onEpisodes() } }
                            control("pip.enter",label:"画中画") { pictureWindow.toggle() }
                            control(fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",label:fullscreen ? "退出全屏":"全屏") { onFullscreen() }
                            control("goforward",label:"快进17秒",text:"+17") { model.jump(17); reveal() }
                        }
                        timeline
                    }
                    .padding(fullscreen ? 20 : 12)
                    .transition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .clipped()
            .onAppear { pictureWindow.onActiveChanged = { model.pictureInPicture = $0 }; reveal() }
            .onDisappear { hideTask?.cancel(); if holding && model.playing { model.player.rate = speedBeforeHold } }
        }
        .background(.black)
    }

    private var timeline: some View {
        HStack(spacing:10) {
            Text(stamp(seekPreview ?? model.position))
            Slider(value: Binding(get: { min(max(0,seekPreview ?? model.position),max(1,model.duration)) },set: { seekPreview = $0 }),
                   in:0...max(1,model.duration),onEditingChanged: { editing in
                seekingSlider = editing
                if !editing, let value = seekPreview { model.seek(value); seekPreview = nil; reveal() }
            }).tint(accent).accessibilityLabel("播放进度")
            Text(stamp(model.duration))
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal,10).padding(.vertical,6)
        .background(.black.opacity(0.36),in:Capsule())
    }

    private func control(_ symbol:String,label:String,text:String? = nil,action:@escaping () -> Void) -> some View {
        Button(action:action) {
            Group { if let text { Text(text).font(.callout.bold()) } else { Image(systemName:symbol).font(.callout.weight(.semibold)) } }
                .frame(minWidth:fullscreen ? 38 : 32,minHeight:fullscreen ? 38 : 32)
                .background(.black.opacity(0.42),in:Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
    private func stamp(_ seconds:Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let n = max(0,Int(seconds)); return n >= 3600 ? String(format:"%d:%02d:%02d",n/3600,(n/60)%60,n%60) : String(format:"%02d:%02d",n/60,n%60)
    }
    private func reveal() {
        withAnimation(.easeInOut(duration:0.2)) { controlsVisible = true }
        hideTask?.cancel()
        // In the split-screen player, keep the compact controls visible so a tap
        // cannot immediately race with the full-screen auto-hide timer.
        guard fullscreen else { return }
        hideTask = Task { try? await Task.sleep(for:.seconds(3.5)); if !Task.isCancelled && !seekingSlider { withAnimation { controlsVisible = false } } }
    }
    private func signal(_ message:String) {
        feedback = message; reveal()
        Task { try? await Task.sleep(for:.seconds(1)); if feedback == message { feedback = "" } }
    }
    private func updateDrag(_ value:DragGesture.Value,size:CGSize) {
        if gestureKind == 0 {
            if abs(value.translation.width) > abs(value.translation.height) {
                gestureKind = 1; dragStart = model.position
            } else {
                gestureKind = value.startLocation.x < size.width/2 ? 2 : 3
                dragStart = gestureKind == 2 ? Double(UIScreen.main.brightness) : Double(model.player.volume)
            }
        }
        if gestureKind == 1 {
            let duration = max(model.duration,120)
            seekPreview = min(max(0,dragStart + Double(value.translation.width / max(1,size.width)) * duration),duration)
            feedback = "跳转到 " + stamp(seekPreview ?? 0)
        } else {
            let value = min(max(0,dragStart - Double(value.translation.height / max(1,size.height))),1)
            if gestureKind == 2 { UIScreen.main.brightness = CGFloat(value); feedback = "亮度 \(Int(value*100))%" }
            else { model.player.volume = Float(value); feedback = "应用音量 \(Int(value*100))%" }
        }
    }
    private func endDrag(_ value:DragGesture.Value,size:CGSize) {
        if gestureKind == 1, let target = seekPreview { model.seek(target) }
        gestureKind = 0; seekPreview = nil; feedback = ""; reveal()
    }
}
