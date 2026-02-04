import 'package:flutter/material.dart';

// 날씨 타입 정의
enum WeatherType { 
  sunny, 
  rainy, 
  snowy, 
  night, 
  blossom, 
  dawn,
  cloudy // 새로 추가됨
}

// 배경 그라데이션 가져오기
LinearGradient getWeatherGradient(WeatherType type) {
  switch (type) {
    case WeatherType.sunny:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
      );
    case WeatherType.rainy:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4B6CB7), Color(0xFF182848)],
      );
    case WeatherType.snowy:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE6DADA), Color(0xFF274046)],
      );
    case WeatherType.night:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      );
    case WeatherType.blossom:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFff9a9e), Color(0xFFfad0c4)],
      );
    case WeatherType.dawn:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFcc2b5e), Color(0xFF753a88)],
      );
    case WeatherType.cloudy:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBDC3C7), Color(0xFF2C3E50)], // 흐린 날 색상
      );
  }
}

// 텍스트 색상 가져오기
Color getTextColor(WeatherType type) {
  switch (type) {
    case WeatherType.sunny:
    case WeatherType.blossom:
    case WeatherType.cloudy:
      return Colors.white; 
    default:
      return Colors.white;
  }
}