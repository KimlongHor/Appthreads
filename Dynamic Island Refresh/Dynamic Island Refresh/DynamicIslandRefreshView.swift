//
//  DynamicIslandRefreshView.swift
//  Dynamic Island Refresh
//
//  Created by Kimlong Hor on 12/22/23.
//

import SwiftUI

struct DynamicIslandRefreshView<Content: View>: View {
    var content: Content
    var showIndicator: Bool
    var onRefresh: () async -> ()
    init(showIndicator: Bool = false, @ViewBuilder content: @escaping () -> Content, onRefresh: @escaping () async -> ()) {
        self.content = content()
        self.showIndicator = showIndicator
        self.onRefresh = onRefresh
    }
    
    @StateObject var scrollDelegate: ScrollViewModel = .init()
    var body: some View {
        ScrollView(.vertical, showsIndicators: showIndicator) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 150 * scrollDelegate.progress)
                content
            }
            .offset(coordinateSpace: "scrolling") { offset in
                let newOffset = offset - 59 // default = 59
                scrollDelegate.contentOffset = newOffset
                
                if !scrollDelegate.isScrollable {
                    var progress = newOffset / 150
                    progress = (progress < 0 ? 0 : progress)
                    progress = (progress > 1 ? 1 : progress)
                    scrollDelegate.scrollOffset = newOffset
                    scrollDelegate.progress = progress
                }

                if scrollDelegate.isScrollable && !scrollDelegate.isRefreshing {
                    scrollDelegate.isRefreshing = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        .overlay(alignment: .top, content: {
            ZStack{
                Capsule()
                    .fill(.black)
            }
            .frame(width: 126, height: 37)
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: 11)
            .overlay(alignment: .top, content: {
                Canvas { context, size in
                    context.addFilter(.alphaThreshold(min: 0.5, color: .black))
                    context.addFilter(.blur(radius: 10))
                    context.drawLayer { ctx in
                        for i in [1,2] {
                            if let resolvedView = context.resolveSymbol(id: i) {
                                ctx.draw(resolvedView, at: CGPoint(x: size.width / 2, y: 30))
                            }
                        }
                    }
                } symbols: {
                    CanvasSymbol().tag(1)
                    CanvasSymbol(isCircle: true).tag(2)
                }
                .allowsHitTesting(false)
            })
            .overlay(alignment: .top, content: {
                RefreshView()
                    .offset(y: 11)
            })
            .ignoresSafeArea()
        })
        .onAppear(perform: scrollDelegate.addGesture)
        .onDisappear(perform: scrollDelegate.removeGesture)
        .onChange(of: scrollDelegate.isRefreshing) { newValue in
            if newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await onRefresh()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollDelegate.progress = 0
                        scrollDelegate.isScrollable = false
                        scrollDelegate.isRefreshing = false
                        scrollDelegate.scrollOffset = -7
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollDelegate.scrollOffset = 0
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func CanvasSymbol(isCircle: Bool = false) -> some View {
        if isCircle {
            let centerOffset = scrollDelegate.isScrollable ? (scrollDelegate.contentOffset > 95 ? scrollDelegate.contentOffset : 95) : scrollDelegate.contentOffset
            let offset = scrollDelegate.scrollOffset > -7 ? centerOffset : -7
            
            // 1 - 0.74 = 0.26
            let scaling = scrollDelegate.progress * 0.26
            Circle()
                .fill(.black)
                .frame(width: 50, height: 50)
                .scaleEffect(0.74 + scaling, anchor: .center) // Dynamic island height = 37, 37/50 = 0.74
                .offset(y: offset)
        } else {
            Capsule()
                .fill(.black)
                .frame(width: 126, height: 35)
        }
    }
    
    @ViewBuilder
    func RefreshView() -> some View {
        let centerOffset = scrollDelegate.isScrollable ? (scrollDelegate.contentOffset > 95 ? scrollDelegate.contentOffset : 95) : scrollDelegate.contentOffset
        let offset = scrollDelegate.scrollOffset > 0 ? centerOffset : 0

        ZStack {
            Image(systemName: "arrow.down")
                .font(.callout.bold())
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .rotationEffect(.init(degrees: scrollDelegate.progress * 180))
                .opacity(scrollDelegate.isScrollable ? 0 : 1)
            ProgressView()
                .tint(.white)
                .frame(width: 38, height: 38)
                .opacity(scrollDelegate.isScrollable ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: scrollDelegate.isScrollable)
        .opacity(scrollDelegate.progress)
        .offset(y: offset)
    }
}

struct CustomRefreshView_Previews: PreviewProvider {
    static var previews: some View {
        DynamicIslandRefreshView(showIndicator: false) {
            // ...
        } onRefresh: {}
    }
}

class ScrollViewModel: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    @Published var isScrollable: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var contentOffset: CGFloat = 0
    @Published var progress: CGFloat = 0
    
    let gestureID = UUID().uuidString
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func addGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onGestureChange(gesture:)))
        panGesture.name = gestureID
        panGesture.delegate = self
        rootController().view.addGestureRecognizer(panGesture)
    }
    
    func removeGesture() {
        rootController().view.gestureRecognizers?.removeAll(where: { gesture in
            gesture.name == gestureID
        })
    }
    
    func rootController() -> UIViewController {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .init()
        }
        
        guard let rootViewController = screen.windows.first?.rootViewController else {
            return .init()
        }
        
        return rootViewController
    }
    
    @objc func onGestureChange(gesture: UIPanGestureRecognizer) {
        if gesture.state == .cancelled || gesture.state == .ended {
            if !isRefreshing {
                if scrollOffset > 150 {
                    isScrollable = true
                } else {
                    isScrollable = false
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func offset(coordinateSpace: String, offset: @escaping (CGFloat) -> ()) -> some View {
        self.overlay {
            GeometryReader { proxy in
                let minY = proxy.frame(in: .named(coordinateSpace)).minY

                Color.clear
                    .preference(key: OffsetKey.self, value: minY)
                    .onPreferenceChange(OffsetKey.self) { value in
                        offset(value)
                    }
            }
        }
    }
}

struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
