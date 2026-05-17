// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final _registeredViews = <String>{};

class FileViewer extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int currentPage;
  const FileViewer({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.currentPage = 1,
  });

  String _buildPdfJsSrcdoc(String url, int page) {
    // Use PDF.js CDN to render a single page cleanly — no browser toolbar, no controls
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%; height: 100%;
    background: #111827;
    display: flex; align-items: center; justify-content: center;
    overflow: hidden;
  }
  #stage {
    display: flex; align-items: center; justify-content: center;
    width: 100%; height: 100%;
  }
  canvas {
    display: block;
    max-width: 100%; max-height: 100%;
    box-shadow: 0 8px 40px rgba(0,0,0,0.7);
    border-radius: 4px;
  }
  #msg {
    position: absolute;
    color: #9ca3af;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    text-align: center;
    padding: 24px;
  }
  #counter {
    position: absolute;
    bottom: 12px;
    right: 16px;
    color: rgba(255,255,255,0.35);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 12px;
    pointer-events: none;
  }
</style>
</head>
<body>
<div id="stage">
  <div id="msg">Loading…</div>
  <canvas id="pdf-canvas" style="display:none"></canvas>
</div>
<div id="counter"></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<script>
  pdfjsLib.GlobalWorkerOptions.workerSrc =
    'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

  const pdfUrl  = ${_jsString(url)};
  const pageNum = $page;

  pdfjsLib.getDocument({ url: pdfUrl, withCredentials: false }).promise
    .then(function(pdf) {
      var total = pdf.numPages;
      document.getElementById('counter').textContent = pageNum + ' / ' + total;

      // Clamp to valid range
      var safeNum = Math.min(Math.max(pageNum, 1), total);
      return pdf.getPage(safeNum);
    })
    .then(function(page) {
      document.getElementById('msg').style.display = 'none';
      var canvas = document.getElementById('pdf-canvas');
      canvas.style.display = 'block';
      var ctx = canvas.getContext('2d');

      var dpr  = window.devicePixelRatio || 1;
      var vw   = window.innerWidth  || 800;
      var vh   = window.innerHeight || 600;

      // Reserve some padding so slide doesn't touch edges
      var availW = vw  - 32;
      var availH = vh  - 32;

      var baseVp  = page.getViewport({ scale: 1 });
      var scaleX  = availW / baseVp.width;
      var scaleY  = availH / baseVp.height;
      var scale   = Math.min(scaleX, scaleY) * dpr;

      var vp = page.getViewport({ scale: scale });
      canvas.width  = vp.width;
      canvas.height = vp.height;
      canvas.style.width  = (vp.width  / dpr) + 'px';
      canvas.style.height = (vp.height / dpr) + 'px';

      return page.render({ canvasContext: ctx, viewport: vp }).promise;
    })
    .catch(function(err) {
      document.getElementById('msg').textContent =
        'Could not load slide ' + pageNum + '.\\n' + err.message;
    });
</script>
</body>
</html>''';
  }

  static String _jsString(String s) {
    // Safely encode URL for inline JS string literal
    final escaped = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    return "'$escaped'";
  }

  @override
  Widget build(BuildContext context) {
    final lower = fileName.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isPptx = lower.endsWith('.pptx') || lower.endsWith('.ppt');

    // Each page gets a unique view ID so page changes force a fresh render
    final viewId = 'doc-viewer-${fileUrl.hashCode.abs()}-p$currentPage';

    if (!_registeredViews.contains(viewId)) {
      _registeredViews.add(viewId);

      if (isPdf) {
        // PDF.js rendered via srcdoc — clean slide canvas, no browser UI
        final srcdoc = _buildPdfJsSrcdoc(fileUrl, currentPage);
        ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
          return html.IFrameElement()
            ..srcdoc = srcdoc
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;
        });
      } else if (isPptx) {
        // Microsoft Office Online — wdSlideNum forces the viewer to open on the
        // correct slide so lecturer and students always stay in sync.
        final src =
            'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(fileUrl)}&wdSlideNum=$currentPage';
        ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
          return html.IFrameElement()
            ..src = src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;
        });
      } else {
        // Fallback: Google Docs viewer for anything else
        final src =
            'https://docs.google.com/viewer?url=${Uri.encodeComponent(fileUrl)}&embedded=true';
        ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
          return html.IFrameElement()
            ..src = src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true;
        });
      }
    }

    return HtmlElementView(viewType: viewId);
  }
}
