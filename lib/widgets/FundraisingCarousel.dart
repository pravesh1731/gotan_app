import 'dart:async';
import 'package:flutter/material.dart';

class FundraisingCarousel extends StatefulWidget {
  @override
  _FundraisingCarouselState createState() => _FundraisingCarouselState();
}

class _FundraisingCarouselState extends State<FundraisingCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<String> _imagePaths = [
    'assets/images/fund/frist.jpeg',
    'assets/images/fund/second.jpeg',
    'assets/images/fund/third.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-scroll timer
    Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_currentPage < _imagePaths.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _imagePaths.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.asset(
                  _imagePaths[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
