import 'package:flutter/material.dart';
import 'package:highlight/highlight_core.dart' as highlight_core;
import 'package:highlight/languages/bash.dart' as bash_language;
import 'package:highlight/languages/cmake.dart' as cmake_language;
import 'package:highlight/languages/cpp.dart' as cpp_language;
import 'package:highlight/languages/cs.dart' as cs_language;
import 'package:highlight/languages/css.dart' as css_language;
import 'package:highlight/languages/dart.dart' as dart_language;
import 'package:highlight/languages/dockerfile.dart' as dockerfile_language;
import 'package:highlight/languages/go.dart' as go_language;
import 'package:highlight/languages/gradle.dart' as gradle_language;
import 'package:highlight/languages/groovy.dart' as groovy_language;
import 'package:highlight/languages/ini.dart' as ini_language;
import 'package:highlight/languages/java.dart' as java_language;
import 'package:highlight/languages/javascript.dart' as javascript_language;
import 'package:highlight/languages/json.dart' as json_language;
import 'package:highlight/languages/kotlin.dart' as kotlin_language;
import 'package:highlight/languages/less.dart' as less_language;
import 'package:highlight/languages/lua.dart' as lua_language;
import 'package:highlight/languages/makefile.dart' as makefile_language;
import 'package:highlight/languages/markdown.dart' as markdown_language;
import 'package:highlight/languages/objectivec.dart' as objectivec_language;
import 'package:highlight/languages/php.dart' as php_language;
import 'package:highlight/languages/protobuf.dart' as protobuf_language;
import 'package:highlight/languages/python.dart' as python_language;
import 'package:highlight/languages/ruby.dart' as ruby_language;
import 'package:highlight/languages/rust.dart' as rust_language;
import 'package:highlight/languages/scss.dart' as scss_language;
import 'package:highlight/languages/sql.dart' as sql_language;
import 'package:highlight/languages/swift.dart' as swift_language;
import 'package:highlight/languages/typescript.dart' as typescript_language;
import 'package:highlight/languages/vue.dart' as vue_language;
import 'package:highlight/languages/xml.dart' as xml_language;
import 'package:highlight/languages/yaml.dart' as yaml_language;

class ChangedFileSyntaxPalette {
  const ChangedFileSyntaxPalette({
    required this.base,
    required this.comment,
    required this.keyword,
    required this.string,
    required this.number,
    required this.type,
    required this.symbol,
    required this.function,
    required this.attribute,
    required this.meta,
    required this.variable,
  });

  final Color base;
  final Color comment;
  final Color keyword;
  final Color string;
  final Color number;
  final Color type;
  final Color symbol;
  final Color function;
  final Color attribute;
  final Color meta;
  final Color variable;
}

class ChangedFileSyntaxHighlighter {
  ChangedFileSyntaxHighlighter._();

  static final highlight_core.Highlight _highlighter =
      highlight_core.Highlight()
        ..registerLanguage('bash', bash_language.bash)
        ..registerLanguage('cmake', cmake_language.cmake)
        ..registerLanguage('cpp', cpp_language.cpp)
        ..registerLanguage('cs', cs_language.cs)
        ..registerLanguage('css', css_language.css)
        ..registerLanguage('dart', dart_language.dart)
        ..registerLanguage('dockerfile', dockerfile_language.dockerfile)
        ..registerLanguage('go', go_language.go)
        ..registerLanguage('gradle', gradle_language.gradle)
        ..registerLanguage('groovy', groovy_language.groovy)
        ..registerLanguage('ini', ini_language.ini)
        ..registerLanguage('java', java_language.java)
        ..registerLanguage('javascript', javascript_language.javascript)
        ..registerLanguage('json', json_language.json)
        ..registerLanguage('kotlin', kotlin_language.kotlin)
        ..registerLanguage('less', less_language.less)
        ..registerLanguage('lua', lua_language.lua)
        ..registerLanguage('makefile', makefile_language.makefile)
        ..registerLanguage('markdown', markdown_language.markdown)
        ..registerLanguage('objectivec', objectivec_language.objectivec)
        ..registerLanguage('php', php_language.php)
        ..registerLanguage('protobuf', protobuf_language.protobuf)
        ..registerLanguage('python', python_language.python)
        ..registerLanguage('ruby', ruby_language.ruby)
        ..registerLanguage('rust', rust_language.rust)
        ..registerLanguage('scss', scss_language.scss)
        ..registerLanguage('sql', sql_language.sql)
        ..registerLanguage('swift', swift_language.swift)
        ..registerLanguage('typescript', typescript_language.typescript)
        ..registerLanguage('vue', vue_language.vue)
        ..registerLanguage('xml', xml_language.xml)
        ..registerLanguage('yaml', yaml_language.yaml);

  static TextSpan buildTextSpan({
    required String source,
    required String? language,
    required TextStyle baseStyle,
    required ChangedFileSyntaxPalette palette,
  }) {
    if (language == null || source.isEmpty) {
      return TextSpan(text: source, style: baseStyle);
    }

    try {
      final result = _highlighter.parse(source, language: language);
      final nodes = result.nodes;
      if (nodes == null || nodes.isEmpty) {
        return TextSpan(text: source, style: baseStyle);
      }

      return TextSpan(
        style: baseStyle.copyWith(color: palette.base),
        children: _spansForNodes(
          nodes: nodes,
          baseStyle: baseStyle,
          palette: palette,
        ),
      );
    } catch (_) {
      return TextSpan(text: source, style: baseStyle);
    }
  }

  static List<InlineSpan> _spansForNodes({
    required List<highlight_core.Node> nodes,
    required TextStyle baseStyle,
    required ChangedFileSyntaxPalette palette,
  }) {
    return nodes
        .map(
          (node) =>
              _spanForNode(node: node, baseStyle: baseStyle, palette: palette),
        )
        .toList(growable: false);
  }

  static InlineSpan _spanForNode({
    required highlight_core.Node node,
    required TextStyle baseStyle,
    required ChangedFileSyntaxPalette palette,
  }) {
    final style = _styleForClassName(
      className: node.className,
      baseStyle: baseStyle,
      palette: palette,
    );
    if (node.value != null) {
      return TextSpan(text: node.value, style: style);
    }

    final children = node.children;
    if (children == null || children.isEmpty) {
      return TextSpan(style: style);
    }

    return TextSpan(
      style: style,
      children: _spansForNodes(
        nodes: children,
        baseStyle: style,
        palette: palette,
      ),
    );
  }

  static TextStyle _styleForClassName({
    required String? className,
    required TextStyle baseStyle,
    required ChangedFileSyntaxPalette palette,
  }) {
    final classes = className?.split(' ') ?? const <String>[];
    var color = palette.base;
    var fontStyle = FontStyle.normal;
    var fontWeight = baseStyle.fontWeight ?? FontWeight.w500;

    for (final tokenClass in classes) {
      if (tokenClass == 'comment' || tokenClass == 'quote') {
        color = palette.comment;
        fontStyle = FontStyle.italic;
        continue;
      }
      if (tokenClass == 'keyword' ||
          tokenClass == 'selector-tag' ||
          tokenClass == 'subst') {
        color = palette.keyword;
        fontWeight = FontWeight.w700;
        continue;
      }
      if (tokenClass == 'string' ||
          tokenClass == 'regexp' ||
          tokenClass == 'bullet') {
        color = palette.string;
        continue;
      }
      if (tokenClass == 'number' || tokenClass == 'literal') {
        color = palette.number;
        continue;
      }
      if (tokenClass == 'type' ||
          tokenClass == 'built_in' ||
          tokenClass == 'built_in-name') {
        color = palette.type;
        continue;
      }
      if (tokenClass == 'symbol' || tokenClass == 'link') {
        color = palette.symbol;
        continue;
      }
      if (tokenClass == 'title' ||
          tokenClass == 'section' ||
          tokenClass == 'function') {
        color = palette.function;
        fontWeight = FontWeight.w700;
        continue;
      }
      if (tokenClass == 'attr' ||
          tokenClass == 'attribute' ||
          tokenClass == 'selector-id' ||
          tokenClass == 'selector-class') {
        color = palette.attribute;
        continue;
      }
      if (tokenClass == 'meta' ||
          tokenClass == 'meta-keyword' ||
          tokenClass == 'doctag') {
        color = palette.meta;
        continue;
      }
      if (tokenClass == 'variable' ||
          tokenClass == 'template-variable' ||
          tokenClass == 'params') {
        color = palette.variable;
      }
    }

    return baseStyle.copyWith(
      color: color,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
    );
  }
}
