import UIKit

/// Let page content scroll beneath navigation without covering its initial position.
@MainActor
enum BrowserChromeLayout {
    static func apply(topInset: CGFloat, bottomInset: CGFloat? = nil, to scrollView: UIScrollView) {
        guard topInset.isFinite, bottomInset?.isFinite != false else { return }
        let inset = max(0, topInset)
        let bottom = bottomInset.map { max(0, $0) } ?? scrollView.contentInset.bottom
        guard scrollView.contentInset.top != inset || scrollView.contentInset.bottom != bottom else { return }
        let previousOffset = scrollView.contentOffset
        let wasAtTop = previousOffset.y <= -scrollView.adjustedContentInset.top + 1
        var contentInsets = scrollView.contentInset
        contentInsets.top = inset
        contentInsets.bottom = bottom
        scrollView.contentInset = contentInsets
        var indicatorInsets = scrollView.verticalScrollIndicatorInsets
        indicatorInsets.top = inset
        if bottomInset != nil { indicatorInsets.bottom = bottom }
        scrollView.verticalScrollIndicatorInsets = indicatorInsets
        if wasAtTop {
            scrollView.setContentOffset(CGPoint(x: previousOffset.x,
                                               y: -scrollView.adjustedContentInset.top), animated: false)
        } else {
            scrollView.setContentOffset(previousOffset, animated: false)
        }
    }
}
