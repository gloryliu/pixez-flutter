/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:convert';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/selectable_html.dart';
import 'package:pixez/component/text_selection_toolbar.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_text_response.dart';
import 'package:pixez/page/comment/comment_page.dart';
import 'package:pixez/page/novel/component/novel_bookmark_button.dart';
import 'package:pixez/page/novel/search/novel_result_page.dart';
import 'package:pixez/page/novel/user/novel_user_page.dart';
import 'package:pixez/page/novel/viewer/image_text.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as Path;

class NovelViewerPage extends StatefulWidget {
  final int id;
  final NovelStore? novelStore;

  const NovelViewerPage({Key? key, required this.id, this.novelStore})
      : super(key: key);

  @override
  _NovelViewerPageState createState() => _NovelViewerPageState();
}

class _NovelViewerPageState extends State<NovelViewerPage> {
  ScrollController? _controller;
  late NovelStore _novelStore;
  ReactionDisposer? _offsetDisposer;
  double _localOffset = 0.0;

  @override
  void initState() {
    _novelStore = widget.novelStore ?? NovelStore(widget.id, null);
    _offsetDisposer = reaction((_) => _novelStore.bookedOffset, (_) {
      LPrinter.d("jump to ${_novelStore.bookedOffset}");
      _controller?.jumpTo(_novelStore.bookedOffset);
    });
    _novelStore.fetch();
    super.initState();
  }

  @override
  void dispose() {
    _offsetDisposer?.call();
    if (_novelStore.positionBooked) {
      _novelStore.bookPosition(_localOffset);
    }
    _controller?.dispose();
    super.dispose();
  }

  final double leading = 0.9;
  final double textLineHeight = 2;
  final double fontSize = 16;
  TextStyle? _textStyle;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        _textStyle = userSetting.novelTextStyle;
        if (_novelStore.errorMessage != null) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0.0,
              backgroundColor: Colors.transparent,
            ),
            extendBody: true,
            extendBodyBehindAppBar: true,
            body: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(':(',
                        style: Theme.of(context).textTheme.headline4),
                  ),
                  TextButton(
                      onPressed: () {
                        _novelStore.fetch();
                      },
                      child: Text(I18n.of(context).retry)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('${_novelStore.errorMessage}'),
                  )
                ],
              ),
            ),
          );
        }
        if (_novelStore.novelTextResponse != null &&
            _novelStore.novel != null) {
          _textStyle =
              _textStyle ?? Theme.of(context).textTheme.bodyText1!.copyWith();
          if (_controller == null) {
            LPrinter.d("init Controller ${_novelStore.bookedOffset}");
            _controller =
                ScrollController(initialScrollOffset: _novelStore.bookedOffset);
            _controller?.addListener(() {
              _localOffset = _controller!.offset;
            });
          }
          return Scaffold(
            appBar: AppBar(
              elevation: 0.0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).textTheme.bodyText1!.color,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: Text(
                _novelStore.novelTextResponse!.novelText.length.toString(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              backgroundColor: Colors.transparent,
              actions: <Widget>[
                NovelBookmarkButton(
                  novel: _novelStore.novel!,
                ),
                IconButton(
                  onPressed: () {
                    if (_novelStore.positionBooked)
                      _novelStore.deleteBookPosition();
                    else
                      _novelStore.bookPosition(_controller!.offset);
                  },
                  icon: Icon(Icons.history),
                  color: Theme.of(context)
                      .textTheme
                      .bodyText1!
                      .color!
                      .withAlpha(_novelStore.positionBooked ? 225 : 120),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(context).textTheme.bodyText1!.color,
                  ),
                  onPressed: () {
                    _showMessage(context);
                  },
                )
              ],
            ),
            extendBodyBehindAppBar: true,
            body: ListView(
              padding: EdgeInsets.all(0.0),
              controller: _controller,
              children: <Widget>[
                Container(
                  height: MediaQuery.of(context).padding.top + 100,
                ),
                Center(
                    child: Container(
                        height: 160,
                        child:
                            PixivImage(_novelStore.novel!.imageUrls.medium))),
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 16.0, top: 12.0, bottom: 8.0),
                  child: Text(
                    "${_novelStore.novel!.title}",
                    style: Theme.of(context).textTheme.subtitle1,
                  ),
                ),
                //MARK DETAIL NUM,
                _buildNumItem(
                    _novelStore.novelTextResponse!, _novelStore.novel!),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "${_novelStore.novel!.createDate}",
                    style: Theme.of(context).textTheme.overline,
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      runSpacing: 0,
                      children: [
                        for (var f in _novelStore.novel!.tags)
                          buildRow(context, f)
                      ],
                    )),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableHtml(
                          data: _novelStore.novel?.caption ?? ""),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                TextButton(
                    onPressed: () {
                      Leader.push(
                          context,
                          CommentPage(
                            id: _novelStore.id,
                            type: CommentArtWorkType.NOVEL,
                          ));
                    },
                    child: Text(I18n.of(context).view_comment)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ExtendedText(
                    _novelStore.novelTextResponse!.novelText,
                    selectionControls: TranslateTextSelectionControls(),
                    selectionEnabled: true,
                    specialTextSpanBuilder: NovelSpecialTextSpanBuilder(),
                    style: _textStyle,
                  ),
                ),
                Container(
                  height: 10,
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            elevation: 0.0,
            backgroundColor: Colors.transparent,
          ),
          body: Container(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        builder: (context) {
          return StatefulBuilder(builder: (context, setB) {
            return SafeArea(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      child: Icon(Icons.text_fields),
                      margin: EdgeInsets.only(left: 16),
                    ),
                    Container(
                      child: Text(_textStyle!.fontSize!.toInt().toString()),
                      margin: EdgeInsets.only(left: 16),
                    ),
                    Expanded(
                        child: Slider(
                            value: _textStyle!.fontSize! / 32,
                            onChanged: (v) {
                              setB(() {
                                _textStyle =
                                    _textStyle!.copyWith(fontSize: v * 32);
                              });
                              userSetting.setNovelFontsizeWithoutSave(v * 32);
                            })),
                  ],
                )
              ],
            ));
          });
        });
    userSetting.setNovelFontsize(_textStyle!.fontSize!);
  }

  Future _longPressTag(BuildContext context, Tag f) async {
    switch (await showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(f.name),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 0);
                },
                child: Text(I18n.of(context).ban),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 2);
                },
                child: Text(I18n.of(context).copy),
              ),
            ],
          );
        })) {
      case 0:
        {
          await muteStore.insertBanTag(BanTagPersist(
              name: f.name, translateName: f.translatedName ?? ""));
          Navigator.of(context).pop();
        }
        break;
      case 2:
        {
          await Clipboard.setData(ClipboardData(text: f.name));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: Duration(seconds: 1),
            content: Text(I18n.of(context).copied_to_clipboard),
          ));
        }
    }
  }

  Widget buildRow(BuildContext context, Tag f) {
    return GestureDetector(
      onLongPress: () async {
        _longPressTag(context, f);
      },
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return NovelResultPage(
            word: f.name,
            translatedName: f.translatedName ?? "",
          );
        }));
      },
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
              text: "#${f.name}",
              children: [
                TextSpan(
                  text: " ",
                  style: Theme.of(context).textTheme.caption,
                ),
                TextSpan(
                    text: "${f.translatedName ?? "~"}",
                    style: Theme.of(context).textTheme.caption)
              ],
              style: Theme.of(context)
                  .textTheme
                  .caption!
                  .copyWith(color: Theme.of(context).colorScheme.secondary))),
    );
  }

  Widget _buildNumItem(NovelTextResponse resp, Novel novel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 0,
        children: [
          Text(I18n.of(context).total_bookmark),
          Text(
            "${novel.totalBookmarks}",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(I18n.of(context).total_view),
          ),
          Text(
            "${novel.totalView}",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Future _showMessage(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  subtitle: Text(
                    _novelStore.novel!.user.name,
                    maxLines: 2,
                  ),
                  title: Text(
                    _novelStore.novel!.title,
                    maxLines: 2,
                  ),
                  leading: PainterAvatar(
                    url: _novelStore.novel!.user.profileImageUrls.medium,
                    id: _novelStore.novel!.user.id,
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        return NovelUserPage(
                          id: _novelStore.novel!.user.id,
                        );
                      }));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Pre'),
                ),
                buildListTile(_novelStore.novelTextResponse!.seriesPrev),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Next'),
                ),
                buildListTile(_novelStore.novelTextResponse!.seriesNext),
                if (Platform.isAndroid)
                  ListTile(
                    title: Text(I18n.of(context).export),
                    leading: Icon(Icons.folder_zip),
                    onTap: () {
                      _export();
                    },
                  ),
                ListTile(
                  title: Text(I18n.of(context).setting),
                  leading: Icon(
                    Icons.settings,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSettings(context);
                  },
                ),
                ListTile(
                  title: Text(I18n.of(context).share),
                  leading: Icon(
                    Icons.share,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Share.share(
                        "https://www.pixiv.net/novel/show.php?id=${widget.id}");
                  },
                ),
              ],
            ),
          );
        });
  }

  Widget buildListTile(TextNovel? series) {
    if (series == null || series.title == null || series.id == null)
      return ListTile(
        title: Text("no more"),
      );
    return ListTile(
      title: Text(series.title!),
      onTap: () {
        Navigator.of(context, rootNavigator: true)
            .pushReplacement(MaterialPageRoute(
                builder: (BuildContext context) => NovelViewerPage(
                      id: series.id!,
                      novelStore: NovelStore(series.id!, null),
                    )));
      },
    );
  }

  void _export() async {
    if (_novelStore.novelTextResponse == null) return;
    if (Platform.isAndroid) {
      final path = await getExternalStorageDirectory();
      if (path == null) return;
      final dirPath = Path.join(path.path, "novel_export");
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final allPath = Path.join(dirPath, "All");
      final allDir = Directory(allPath);
      if (!allDir.existsSync()) {
        allDir.createSync(recursive: true);
      }
      final novelDirPath =
          Path.join(dirPath, _novelStore.novel!.title.trim().toLegal());
      final novelDir = Directory(novelDirPath);
      if (!novelDir.existsSync()) {
        novelDir.createSync(recursive: true);
      }
      final fileInAllPath = Path.join(
          allPath, "${_novelStore.novel!.title.trim().toLegal()}.txt");
      final filePath = Path.join(novelDirPath, "${_novelStore.novel!.id}.txt");
      final resultFile = File(filePath);
      final data = _novelStore.novelTextResponse!.novelText;
      // final json = jsonEncode(_novelStore.novelTextResponse!.toJson());
      resultFile.writeAsStringSync(data);
      File(fileInAllPath).writeAsStringSync(data);
      // File(jsonPath).writeAsStringSync(json);
      LPrinter.d("path: $filePath");
      BotToast.showText(text: "export ${filePath}");
    } else if (Platform.isIOS) {
      final path = await getApplicationDocumentsDirectory();
      if (path == null) return;
      final dirPath = Path.join(path.path, "novel_export");
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final allPath = Path.join(dirPath, "All");
      final allDir = Directory(allPath);
      if (!allDir.existsSync()) {
        allDir.createSync(recursive: true);
      }
      final novelDirPath =
          Path.join(dirPath, _novelStore.novel!.title.trim().toLegal());
      final novelDir = Directory(novelDirPath);
      if (!novelDir.existsSync()) {
        novelDir.createSync(recursive: true);
      }
      final fileInAllPath = Path.join(
          allPath, "${_novelStore.novel!.title.trim().toLegal()}.txt");
      final filePath = Path.join(novelDirPath, "${_novelStore.novel!.id}.txt");
      final resultFile = File(filePath);
      final data = _novelStore.novelTextResponse!.novelText;
      resultFile.writeAsStringSync(data);
      File(fileInAllPath).writeAsStringSync(data);
      LPrinter.d("path: $filePath");
      BotToast.showText(text: "export ${filePath}");
    }
  }
}
