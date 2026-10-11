import UIKit

/// Let page content scroll beneath navigation without covering its initial position.
@MainActor
enum BrowserChromeLayout {
    static func apply(topInset: CGFloat, to scrollView: UIScrollView) {
        guard topInset.isFinite else { return }
        let inset = max(0, topInset)
        guard scrollView.contentInset.top != inset else { return }
        let previousOffset = scrollView.contentOffset
        let wasAtTop = previousOffset.y <= -scrollView.adjustedContentInset.top + 1
        var contentInsets = scrollView.contentInset
        contentInsets.top = inset
        scrollView.contentInset = contentInsets
        var indicatorInsets = scrollView.verticalScrollIndicatorInsets
        indicatorInsets.top = inset
        scrollView.verticalScrollIndicatorInsets = indicatorInsets
        if wasAtTop {
            scrollView.setContentOffset(CGPoint(x: previousOffset.x,
                                               y: -scrollView.adjustedContentInset.top), animated: false)
        } else {
            scrollView.setContentOffset(previousOffset, animated: false)
        }
    }
}
