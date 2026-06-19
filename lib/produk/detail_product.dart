import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobileprogramming_p12/model/Product.dart';
import 'package:mobileprogramming_p12/produk/add_product.dart';
import 'package:mobileprogramming_p12/service/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _currentProduct;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  Future<void> _refreshProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProduct = await ApiService.getProductById(_currentProduct.id);
      setState(() {
        _currentProduct = updatedProduct;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Apakah Anda yakin ingin menghapus "${_currentProduct.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.deleteProduct(_currentProduct.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus produk: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddProductScreen(product: _currentProduct),
                  ),
                );
                if (result == true) {
                  _refreshProductDetails();
                }
              } else if (value == 'delete') {
                _deleteProduct();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImage(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentProduct.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentProduct.formattedPrice,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentProduct.stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentProduct.stockStatus,
                            style: TextStyle(
                              color: _currentProduct.stockColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Deskripsi Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentProduct.descriptions,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProductImage() {
    if (_currentProduct.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentProduct.imageUrl,
        height: 300,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 300,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 300,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      );
    } else {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }
  }
}