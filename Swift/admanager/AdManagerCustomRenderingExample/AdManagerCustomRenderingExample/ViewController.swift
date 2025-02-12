//
//  Copyright (C) 2015 Google, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import GoogleMobileAds
import UIKit

class ViewController: UIViewController {

  // The view that holds the native ad.
  @IBOutlet weak var nativeAdPlaceholder: UIView!

  // Displays status messages about presence of video assets.
  @IBOutlet weak var videoStatusLabel: UILabel!

  // The app install ad switch.
  @IBOutlet weak var nativeAdSwitch: UISwitch!

  // The custom native ad switch.
  @IBOutlet weak var customNativeAdSwitch: UISwitch!

  // The refresh ad button.
  @IBOutlet weak var refreshAdButton: UIButton!

  // The SDK version label.
  @IBOutlet weak var versionLabel: UILabel!

  // Switch to indicate if video ads should start muted.
  @IBOutlet weak var startMutedSwitch: UISwitch!

  /// The ad loader. You must keep a strong reference to the GADAdLoader during the ad loading
  /// process.
  var adLoader: GADAdLoader!

  /// The native ad view that is being presented.
  var nativeAdView: UIView?

  /// The ad unit ID.
  let adUnitID = "/6499/example/native"

  /// The native custom format id
  let nativeCustomFormatId = "10104090"

  override func viewDidLoad() {
    super.viewDidLoad()
    versionLabel.text = GADGetStringFromVersionNumber(GADMobileAds.sharedInstance().versionNumber)
    refreshAd(nil)
  }

  func setAdView(_ view: UIView) {
    // Remove the previous ad view.
    nativeAdView?.removeFromSuperview()
    nativeAdView = view
    nativeAdPlaceholder.addSubview(nativeAdView!)
    nativeAdView!.translatesAutoresizingMaskIntoConstraints = false

    // Layout constraints for positioning the native ad view to stretch the entire width and height
    // of the nativeAdPlaceholder.
    let viewDictionary = ["_nativeAdView": nativeAdView!]
    self.view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "H:|[_nativeAdView]|",
        options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: viewDictionary)
    )
    self.view.addConstraints(
      NSLayoutConstraint.constraints(
        withVisualFormat: "V:|[_nativeAdView]|",
        options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: viewDictionary)
    )
  }

  // MARK: - Actions

  /// Refreshes the native ad.
  @IBAction func refreshAd(_ sender: AnyObject!) {
    var adTypes = [GADAdLoaderAdType]()
    if nativeAdSwitch.isOn {
      adTypes.append(.native)
    }
    if customNativeAdSwitch.isOn {
      adTypes.append(.customNative)
    }

    if adTypes.isEmpty {
      let alert = UIAlertController(
        title: "Alert",
        message: "At least one ad format must be selected to refresh the ad.",
        preferredStyle: .alert)
      let alertAction = UIAlertAction(
        title: "OK",
        style: .cancel,
        handler: nil)
      alert.addAction(alertAction)
      self.present(alert, animated: true, completion: nil)
    } else {
      refreshAdButton.isEnabled = false
      let videoOptions = GADVideoOptions()
      videoOptions.startMuted = startMutedSwitch.isOn
      adLoader = GADAdLoader(
        adUnitID: adUnitID, rootViewController: self,
        adTypes: adTypes, options: [videoOptions])
      adLoader.delegate = self
      adLoader.load(GADRequest())
      videoStatusLabel.text = ""
    }
  }

  /// Returns a `UIImage` representing the number of stars from the given star rating; returns `nil`
  /// if the star rating is less than 3.5 stars.
  func imageOfStars(fromStarRating starRating: NSDecimalNumber?) -> UIImage? {
    guard let rating = starRating?.doubleValue else {
      return nil
    }
    if rating >= 5 {
      return UIImage(named: "stars_5")
    } else if rating >= 4.5 {
      return UIImage(named: "stars_4_5")
    } else if rating >= 4 {
      return UIImage(named: "stars_4")
    } else if rating >= 3.5 {
      return UIImage(named: "stars_3_5")
    } else {
      return nil
    }
  }

  /// Updates the videoController's delegate and viewController's UI according to videoController
  /// 'hasVideoContent()' value.
  /// Some content ads will include a video asset, while others do not. Apps can use the
  /// GADVideoController's hasVideoContent property to determine if one is present, and adjust their
  /// UI accordingly.
  func updateVideoStatusLabel(hasVideoContent: Bool) {
    if hasVideoContent {
      // By acting as the delegate to the GADVideoController, this ViewController receives messages
      // about events in the video lifecycle.
      videoStatusLabel.text = "Ad contains a video asset."
    } else {
      videoStatusLabel.text = "Ad does not contain a video."
    }
  }

}

// MARK: - GADAdLoaderDelegate

extension ViewController: GADAdLoaderDelegate {

  func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
    print("\(adLoader) failed with error: \(error.localizedDescription)")
    refreshAdButton.isEnabled = true
  }
}

// MARK: - GADNativeAdLoaderDelegate

extension ViewController: GADNativeAdLoaderDelegate {

  func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
    print("Received native ad: \(nativeAd)")
    refreshAdButton.isEnabled = true
    // Create and place ad in view hierarchy.
    let nibView = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first
    guard let nativeAdView = nibView as? GADNativeAdView else {
      return
    }
    setAdView(nativeAdView)

    // Set ourselves as the native ad delegate to be notified of native ad events.
    nativeAd.delegate = self

    // Populate the native ad view with the native ad assets.
    // The headline and mediaContent are guaranteed to be present in every native ad.
    (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
    nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

    // Some native ads will include a video asset, while others do not. Apps can use the
    // GADVideoController's hasVideoContent property to determine if one is present, and adjust their
    // UI accordingly.
    let hasVideoContent = nativeAd.mediaContent.hasVideoContent  // Update the ViewController for video content.
    updateVideoStatusLabel(hasVideoContent: hasVideoContent)
    if hasVideoContent {
      // By acting as the delegate to the GADVideoController, this ViewController receives messages
      // about events in the video lifecycle.
      nativeAd.mediaContent.videoController.delegate = self
    }

    // This app uses a fixed width for the GADMediaView and changes its height to match the aspect
    // ratio of the media it displays.
    if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
      let heightConstraint = NSLayoutConstraint(
        item: mediaView,
        attribute: .height,
        relatedBy: .equal,
        toItem: mediaView,
        attribute: .width,
        multiplier: CGFloat(1 / nativeAd.mediaContent.aspectRatio),
        constant: 0)
      heightConstraint.isActive = true
    }

    // These assets are not guaranteed to be present. Check that they are before
    // showing or hiding them.
    (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
    nativeAdView.bodyView?.isHidden = nativeAd.body == nil

    (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
    nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

    (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
    nativeAdView.iconView?.isHidden = nativeAd.icon == nil

    (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(
      fromStarRating: nativeAd.starRating)
    nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

    (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
    nativeAdView.storeView?.isHidden = nativeAd.store == nil

    (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
    nativeAdView.priceView?.isHidden = nativeAd.price == nil

    (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
    nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

    // In order for the SDK to process touch events properly, user interaction should be disabled.
    nativeAdView.callToActionView?.isUserInteractionEnabled = false

    // Associate the native ad view with the native ad object. This is
    // required to make the ad clickable.
    // Note: this should always be done after populating the ad views.
    nativeAdView.nativeAd = nativeAd
  }
}

// MARK: - GADCustomNativeAdLoaderDelegate

extension ViewController: GADCustomNativeAdLoaderDelegate {
  func customNativeAdFormatIDs(for adLoader: GADAdLoader) -> [String] {
    return [nativeCustomFormatId]
  }

  func adLoader(
    _ adLoader: GADAdLoader,
    didReceive customNativeAd: GADCustomNativeAd
  ) {
    print("Received custom native ad: \(customNativeAd)")
    refreshAdButton.isEnabled = true
    // Create and place the ad in the view hierarchy.
    let customNativeAdView =
      Bundle.main.loadNibNamed(
        "SimpleCustomNativeAdView", owner: nil, options: nil)!.first as! MySimpleNativeAdView
    setAdView(customNativeAdView)

    let hasVideoContent = customNativeAd.mediaContent.hasVideoContent
    // Update the ViewController for video content.
    updateVideoStatusLabel(hasVideoContent: hasVideoContent)
    if hasVideoContent {
      customNativeAd.mediaContent.videoController.delegate = self
    }
    // Populate the custom native ad view with the custom native ad assets.
    customNativeAdView.populate(withCustomNativeAd: customNativeAd)
    // Impressions for custom native ads must be manually tracked. If this is not called,
    // videos will also not be played.
    customNativeAd.recordImpression()
  }
}

// MARK: - GADVideoControllerDelegate implementation
extension ViewController: GADVideoControllerDelegate {

  func videoControllerDidEndVideoPlayback(_ videoController: GADVideoController) {
    videoStatusLabel.text = "Video playback has ended."
  }
}

// MARK: - GADNativeAdDelegate implementation
extension ViewController: GADNativeAdDelegate {

  func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }

  func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillPresentScreen(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillDismissScreen(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }

  func nativeAdDidDismissScreen(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillLeaveApplication(_ nativeAd: GADNativeAd) {
    print("\(#function) called")
  }
}
