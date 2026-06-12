import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';
import '../model/Product.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String storageUrl = 'http://127.0.0.1:8000/storage';

  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    String cleanPath = imagePath;

    if (cleanPath.startsWith('public/')) {
      cleanPath = cleanPath.substring(7);
    }

    while (cleanPath.contains('products/products/')) {
      cleanPath = cleanPath.replaceAll('products/products/', 'products/');
    }

    String base = storageUrl.endsWith('/') ? storageUrl : '$storageUrl/';
    String path = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;

    final String finalUrl = base + path;

    return finalUrl;
  }

  static Future<List<Product>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is List) {
          return decoded.map((json) => Product.fromJson(json)).toList();
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            return (decoded['data'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          } else if (decoded.containsKey('products') && decoded['products'] is List) {
            return (decoded['products'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          } else if (decoded.containsKey('result') && decoded['result'] is List) {
            return (decoded['result'] as List)
                .map((json) => Product.fromJson(json))
                .toList();
          } else {
            return [Product.fromJson(decoded)];
          }
        } else {
          throw Exception('Format response tidak dikenali: ${decoded.runtimeType}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint tidak ditemukan: $baseUrl/products');
      } else {
        throw Exception('Gagal memuat produk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Product> getProductById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        } else {
          throw Exception('Format response tidak dikenali');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Produk tidak ditemukan');
      } else {
        throw Exception('Gagal memuat produk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Product> reduceStock(int productId, int quantity) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/products/$productId/reduce-stock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'quantity': quantity}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        }
        throw Exception('Format response tidak dikenali');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Stok tidak mencukupi');
      } else {
        throw Exception('Gagal mengurangi stok: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> deleteProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Gagal menghapus produk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Product> createProduct({
    required String name,
    required String descriptions,
    required int price,
    required int stock,
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'descriptions': descriptions,
          'price': price,
          'stock': stock,
        }),
      );

      if (response.statusCode == 201) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        }
        throw Exception('Format response tidak dikenali');
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['message'] ?? 'Gagal membuat produk');
        } catch (e) {
          throw Exception('Gagal membuat produk: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Product> updateProduct({
    required int id,
    String? name,
    String? descriptions,
    int? price,
    int? stock,
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/products/$id'),
      );

      request.fields['_method'] = 'PUT';

      if (name != null && name.isNotEmpty) {
        request.fields['name'] = name;
      }
      if (descriptions != null) {
        request.fields['descriptions'] = descriptions;
      }
      if (price != null) {
        request.fields['price'] = price.toString();
      }
      if (stock != null) {
        request.fields['stock'] = stock.toString();
      }

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      } else if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map) {
            return Product.fromJson(decoded['data']);
          }
          return Product.fromJson(decoded);
        }
        throw Exception('Format response tidak dikenali');
      } else {
        try {
          final error = json.decode(responseBody);
          throw Exception(error['message'] ?? 'Gagal update produk');
        } catch (e) {
          throw Exception('Gagal update produk: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

static Future<String> uploadImageBytes(int productId, Uint8List bytes) async {
  try {
    if (bytes.length > 2 * 1024 * 1024) {
      throw Exception('File terlalu besar (max 2MB)');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/products/$productId/upload-image'),
    );

    request.headers['Accept'] = 'application/json';

    var multipartFile = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = json.decode(responseBody);
      return decoded['image_url'] ?? '';
    } else {
      throw Exception('Upload gagal: ${response.statusCode} - $responseBody');
    }
  } catch (e) {
    throw Exception('Gagal upload gambar: $e');
  }
}
}