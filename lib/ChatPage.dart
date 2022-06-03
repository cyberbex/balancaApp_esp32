import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:androidbluetoothserialapp/model/DadosPesagem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import './BluetoothDeviceListEntry.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  var connection; //BluetoothConnection

  TextEditingController controllerNumeroAv = TextEditingController();
  TextEditingController controllerNumeroLote = TextEditingController();
  TextEditingController controllerIdadeLote = TextEditingController();
  TextEditingController controllerLinhagem = TextEditingController();
  TextEditingController controllerRacaoConsumida = TextEditingController();
  TextEditingController controllerCalibrar = TextEditingController();

  List<_Message> messages = [];
  //String _messageBuffer = '';

  List<DadosPesagem> lista_pesagem = [];
  List<DadosPesagem> listaReversa = [];

  bool isConnecting = true;
  bool isDisconnecting = false;

  String dataString = '0.0';
  String numeroAv = '';
  String numeroLote = '';
  String idadeAve = '';
  String racaoConsumida = '';
  String linhagem = '';
  String sexo = '';

  String pesoCalibrar = '';
  bool flagCalibrar = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected()) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  salvarInfo() {
    numeroAv = controllerNumeroAv.text;
    numeroLote = controllerNumeroLote.text;
    idadeAve = controllerIdadeLote.text;
    linhagem = controllerLinhagem.text;
    racaoConsumida = controllerRacaoConsumida.text;
  }

  enviarPeso() {
    String peso = dataString;
    DadosPesagem dados_pesagem = DadosPesagem(peso, racaoConsumida, numeroAv,
        numeroLote, idadeAve, linhagem, sexo, DateTime.now().toString());

    lista_pesagem.add(dados_pesagem);

    setState(() {
      listaReversa = lista_pesagem.reversed.toList();
    });
    /* infoPesagem['peso'] = dataString;
    infoPesagem['sexoAve'] = 'macho';
    setState(() {
      listaPesagem.add(infoPesagem);
    }); */
  }

  enviarPesoConhecido() {
    pesoCalibrar = controllerCalibrar.text;
    _sendMessage(pesoCalibrar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: (isConnecting
            ? Text('Conectando... ')
            : isConnected()
                ? Text('Conectado')
                : Text('Não Conectado')),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.blue,
        child: Row(
          children: [
            Padding(padding: EdgeInsets.only(left: 10)),
            IconButton(
              color: Colors.white,
              onPressed: () {},
              iconSize: 40,
              icon: Icon(Icons.save),
            ),
            Padding(padding: EdgeInsets.only(left: 10)),
            IconButton(
              color: Colors.white,
              onPressed: () {
                _sendMessage("tara");
              },
              iconSize: 40,
              icon: Icon(Icons.tap_and_play_rounded),
            ),
            Padding(padding: EdgeInsets.only(left: 10)),
            IconButton(
              color: Colors.white,
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Info Pesagem"),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              TextField(
                                controller: controllerNumeroAv,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: "Digite o numero do aviário"),
                              ),
                              TextField(
                                controller: controllerNumeroLote,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: "Digite o numero do Lote"),
                              ),
                              TextField(
                                controller: controllerIdadeLote,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: "Digite a idade do Lote"),
                              ),
                              TextField(
                                controller: controllerLinhagem,
                                decoration: InputDecoration(
                                    labelText: "Digite a linhagem"),
                              ),
                              TextField(
                                controller: controllerRacaoConsumida,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: "Total de racao Consumida"),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          ElevatedButton(
                              child: Text("Salvar"),
                              onPressed: () {
                                salvarInfo();
                                Navigator.pop(context);
                              }),
                        ],
                      );
                    });
              },
              iconSize: 40,
              icon: Icon(Icons.add),
            ),
            Padding(padding: EdgeInsets.only(left: 10)),
            IconButton(
              color: Colors.white,
              onPressed: () {
                _sendMessage("calibrar");
                if (flagCalibrar == false) {
                  flagCalibrar = true;
                }

                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(
                            'Coloque um peso conhecido na balança e após aperte em calibrar!!'),
                        actions: [
                          TextField(
                            controller: controllerCalibrar,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(labelText: "Massa conhecida"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              enviarPesoConhecido();
                              flagCalibrar = false;
                              Navigator.pop(context);
                            },
                            child: Text('Calibrar'),
                          ),
                        ],
                      );
                    });
              },
              iconSize: 40,
              icon: Icon(Icons.ac_unit),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 50),
                child: Text(
                  "${dataString}g",
                  style: TextStyle(
                    fontSize: 45,
                    fontStyle: FontStyle.normal,
                    color: Color.fromARGB(255, 81, 80, 85),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              /*  ElevatedButton(
                onPressed: () {
                  _sendMessage("calibrar");

                  //Navigator.push(context, MaterialPageRoute(),
                  //Navigator.of(context).pop(result.device);
                },
                child: Text("Calibrar"),
              ), */

              Padding(padding: EdgeInsets.fromLTRB(90, 40, 10, 50)),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Escolha entre macho ou femea?"),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                sexo = 'Macho';
                                enviarPeso();
                                Navigator.pop(context);
                              },
                              child: Text("Macho"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                sexo = 'Femea';
                                enviarPeso();
                                Navigator.pop(context);
                              },
                              child: Text("Femea"),
                            ),
                          ],
                        );
                      });
                },
                child: Text(
                  "Enviar Peso",
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          /* TextField(
            keyboardType: TextInputType.number,
            onSubmitted: (String texto) {
              _sendMessage(texto);
            },
          ), */

          Expanded(
            child: ListView.builder(
                itemCount: listaReversa.length,
                itemBuilder: (context, index) {
                  final item = listaReversa[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        "Peso: ${item.pesoFrando} gramas  ",
                        style: TextStyle(fontSize: 25),
                      ),
                      subtitle: Text(
                        "Frango ${item.sexoAve} - - Idade: ${item.idadeAve} ",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  );
                }),
          ),
        ],
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    Uint8List buffer = Uint8List(data.length);
    int bufferIndex = buffer.length;

    for (int i = data.length - 1; i >= 0; i--) {
      buffer[--bufferIndex] = data[i];
    }
    setState(() {
      dataString = String.fromCharCodes(buffer);
    });

    //if (dataString == 'runo') print("agora vai vaivai trabalhar!!");
    print(dataString);

    /*   bool ponto = dataString.contains('f');
    if (ponto == true) {
      data1 += dataString;
    } else if (ponto == false) {
      print(data1);
      data1 = "";
    } */

    //bool flag = dataString.contains('unqoMigliori');
    //if (flag)
    //print("pode cre!!");
    //else
    //print('nao tem!!');

    //_sendMessage('Eai esp blz?');
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text));
        await connection.output.allSent;

        //setState(() {
        //  messages.add(_Message(clientID, text));
        //});
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  bool isConnected() {
    return connection != null && connection.isConnected;
  }
}
