import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_example/models/message.dart';
import 'package:firebase_example/screens/auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final firebaseAuthInstance = FirebaseAuth.instance;
final firebaseStorageInstance = FirebaseStorage.instance;
final FirebaseFirestoreInstance = FirebaseFirestore.instance;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final messageController = TextEditingController();
  File? _pickedFile;
  String? _imageUrl;
  DateTime? date;

  @override
  void initState() {
    super.initState();
    _getUserImage();
  }

  void _getUserImage() async {
    final user = firebaseAuthInstance.currentUser;
    final document =
        firebaseFireStoreInstance.collection("users").doc(user!.uid);
    final docSnapshot = await document.get();

    setState(() {
      _imageUrl = docSnapshot.get("imageUrl");
    });
  }

  Future<List<Message>> _getMessages() async {
    final document =
        await firebaseFireStoreInstance.collection("messages").get();

    print(document.docs.first.data());

    final messagesList =
        document.docs.map((e) => Message.fromJson(e.data())).toList();

    // mesajları tarihe göre sıralıyor
    messagesList.sort((a, b) {
      return a.date.compareTo(b.date);
    });

    return messagesList;
  }

  void _pickImage() async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 150);
    if (image != null) {
      setState(() {
        _pickedFile = File(image.path);
      });
    }
  }

  void _upload() async {
    final user = firebaseAuthInstance.currentUser;
    final ref =
        firebaseStorageInstance.ref().child("images").child("${user!.uid}.jpg");

    await ref.putFile(_pickedFile!);
    final url = await ref.getDownloadURL();
    print(url);

    final document =
        firebaseFireStoreInstance.collection("users").doc(user!.uid);

    await document.update({'imageUrl': url});
  }

  void _submitMessage() async {
    final user = firebaseAuthInstance.currentUser;
    date = DateTime.now();

    try {
      firebaseFireStoreInstance.collection("messages").doc().set({
        'message': messageController.text,
        'date': date,
        'userId': user!.uid
      });
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message!)));
    }

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firebase Example"),
        actions: [
          IconButton(
              onPressed: () {
                firebaseAuthInstance.signOut();
              },
              icon: const Icon(Icons.logout))
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    foregroundImage:
                        _imageUrl == null ? null : NetworkImage(_imageUrl!),
                  ),
                  TextButton(
                      onPressed: () {
                        _pickImage();
                      },
                      child: Text("Resim Seç")),
                  _pickedFile != null
                      ? ElevatedButton(
                          onPressed: () {
                            _upload();
                          },
                          child: Text("Resim Yükle"))
                      : Container(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(width: 1, color: Colors.black),
                      borderRadius: BorderRadius.circular(8.0)),
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: FutureBuilder(
                    future: _getMessages(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            if (snapshot.data![index].userId ==
                                firebaseAuthInstance.currentUser!.uid) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: EdgeInsets.all(4.0),
                                  padding: EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          width: 1, color: Colors.black),
                                      borderRadius: BorderRadius.circular(8.0)),
                                  child: Column(
                                    children: [
                                      Text(
                                        snapshot.data![index].message,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: EdgeInsets.all(4.0),
                                  padding: EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          width: 1, color: Colors.black),
                                      borderRadius: BorderRadius.circular(8.0)),
                                  child: Text(
                                    snapshot.data![index].message,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      } else if (snapshot.hasError) {
                        return const Text("Something went wrong.");
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: const InputDecoration(
                            hintText: 'Bir mesaj yazın.',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8.0)))),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.02,
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: IconButton(
                          onPressed: () {
                            _submitMessage();
                          },
                          icon: Icon(Icons.subdirectory_arrow_left)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
