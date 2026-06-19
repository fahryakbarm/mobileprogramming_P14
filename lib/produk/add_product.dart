import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobileprogramming_p12/model/Product.dart';
import 'package:mobileprogramming_p12/service/api_service.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  File? _imageFile;
  XFile? _pickedXFile;
  bool _isLoading = false;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.descriptions;
      _priceController.text = widget.product!.price.toString();
      _stockController.text = widget.product!.stock.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _pickedXFile = pickedFile;
          if (!kIsWeb) {
            _imageFile = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mengambil gambar: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final price = int.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());

      Product savedProduct;

      if (_isEditMode) {
        if (kIsWeb && _pickedXFile != null) {
          final bytes = await _pickedXFile!.readAsBytes();
          savedProduct = await ApiService.updateProduct(
            id: widget.product!.id,
            name: name,
            descriptions: desc,
            price: price,
            stock: stock,
            imageBytes: bytes,
          );
        } else {
          savedProduct = await ApiService.updateProduct(
            id: widget.product!.id,
            name: name,
            descriptions: desc,
            price: price,
            stock: stock,
            imageFile: _imageFile,
          );
        }
      } else {
        if (kIsWeb && _pickedXFile != null) {
          final bytes = await _pickedXFile!.readAsBytes();
          savedProduct = await ApiService.createProduct(
            name: name,
            descriptions: desc,
            price: price,
            stock: stock,
            imageBytes: bytes,
          );
        } else {
          savedProduct = await ApiService.createProduct(
            name: name,
            descriptions: desc,
            price: price,
            stock: stock,
          );

          if (_imageFile != null && !kIsWeb) {
            await ApiService.uploadImage(savedProduct.id, _imageFile!);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Produk berhasil diperbarui' : 'Produk berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan produk: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Produk',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama produk tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Deskripsi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Harga',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Harga harus berupa angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stok',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Stok tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Stok harus berupa angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Foto Produk',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : (_isEditMode && widget.product!.imageUrl.isNotEmpty)
                                ? Image.network(widget.product!.imageUrl, fit: BoxFit.cover)
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Sentuh untuk memilih foto', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_isEditMode ? 'Perbarui Produk' : 'Simpan Produk'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}