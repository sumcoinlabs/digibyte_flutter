import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  final double height;  // Height of the ad container
  final double width;   // Width of the ad container
  final EdgeInsetsGeometry padding;  // Padding around the ad

  BannerAdWidget({
    Key? key,
    this.height = 50.0,
    this.width = double.infinity,
    this.padding = const EdgeInsets.all(10.0), // Default padding added
  }) : super(key: key);

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    loadAd(); // Preloading the ad
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void loadAd() {
    String adUnitId = getAdUnitId();

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _adLoaded = false;
            });
          } else {
            _bannerAd = null;
          }
        },
      ),
    );
    _bannerAd!.load();
  }

  String getAdUnitId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-1492791099222955/1323875636';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-1492791099222955/7755420606';
    }
    return 'your_default_ad_unit_id';
  }

  @override
  Widget build(BuildContext context) {
    if (!_adLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
