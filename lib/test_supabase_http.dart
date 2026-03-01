import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  print('Making request to $url/rest/v1/exercises?select=*');
  
  try {
    final response = await http.get(
      Uri.parse('$url/rest/v1/exercises?select=*'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
      }
    );
    
    print('Status code: \${response.statusCode}');
    print('Body length: \${response.body.length}');
  } catch (e) {
    print('Error: $e');
  }
}
