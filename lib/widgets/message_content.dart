import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight_core.dart' show Node, highlight;
import 'package:markdown/markdown.dart' as md;

import '../config/theme.dart';
import '../utils/links.dart';

/// Renders message content the way the web client does: markdown with
/// syntax highlighted code blocks, and mention tokens drawn as tinted pills.
///
/// Mentions arrive as ids in the content (`<@uuid>`, `<@&roleUuid>`,
/// `@everyone`, `@here`) because the server is what decides who gets
/// notified. Turning an id into a name needs the community directory, so the
/// caller wraps this in a [MentionScope] rather than passing resolvers down
/// through the markdown builders.
class MessageContent extends StatefulWidget {
  const MessageContent({super.key, required this.content});

  final String content;

  @override
  State<MessageContent> createState() => _MessageContentState();
}

class _MessageContentState extends State<MessageContent> {
  final Map<String, TapGestureRecognizer> _recognizers = {};
  MentionScope? _scope;

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(String id) {
    return _recognizers.putIfAbsent(
      id,
      () => TapGestureRecognizer()..onTap = () => _scope?.onMentionTap?.call(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scope = MentionScope.maybeOf(context);
    return MarkdownBody(
      data: widget.content,
      selectable: false,
      softLineBreak: true,
      styleSheet: _styleSheet,
      extensionSet: _extensionSet,
      builders: {
        'mention': _MentionBuilder(recognizerFor: _recognizerFor),
        'pre': _CodeBlockBuilder(),
      },
      onTapLink: (text, href, title) => openExternalLink(context, href),
    );
  }
}

const String _uuidPattern =
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

/// Renders `<@uuid>` and `<@&uuid>` as mention nodes. Mentions inside code
/// spans and code blocks stay literal, since the web client never substitutes
/// there and neither should this.
class _UserMentionSyntax extends md.InlineSyntax {
  _UserMentionSyntax() : super('<@&?($_uuidPattern)>', startCharacter: 0x3C);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match[0]!;
    final isRole = raw.startsWith('<@&');
    final id = raw.substring(isRole ? 3 : 2, raw.length - 1).toLowerCase();
    parser.addNode(
      md.Element.text('mention', '@$id')
        ..attributes['data-id'] = id
        ..attributes['data-kind'] = isRole ? 'role' : 'user',
    );
    return true;
  }
}

class _BroadcastMentionSyntax extends md.InlineSyntax {
  _BroadcastMentionSyntax()
    : super(r'(?<![A-Za-z0-9_@&])@(everyone|here)(?![A-Za-z0-9_])',
        startCharacter: 0x40);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final kind = match[1]!;
    parser.addNode(
      md.Element.text('mention', '@$kind')
        ..attributes['data-id'] = kind
        ..attributes['data-kind'] = kind,
    );
    return true;
  }
}

final md.ExtensionSet _extensionSet = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  [
    _UserMentionSyntax(),
    _BroadcastMentionSyntax(),
    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
  ],
);

/// Turns a mention node into a tinted pill. It returns a text widget rather
/// than an arbitrary widget so the pill stays inline with the words around it
/// instead of being pushed onto its own line.
class _MentionBuilder extends MarkdownElementBuilder {
  _MentionBuilder({required this.recognizerFor});

  final TapGestureRecognizer Function(String id) recognizerFor;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final scope = MentionScope.maybeOf(context);
    final kind = element.attributes['data-kind'] ?? 'user';
    final id = element.attributes['data-id'] ?? '';

    final String? resolved = switch (kind) {
      'role' => scope?.roleName?.call(id),
      'everyone' || 'here' => null,
      _ => scope?.userName.call(id),
    };
    final label = switch (kind) {
      'everyone' => '@everyone',
      'here' => '@here',
      _ =>
        resolved != null && resolved.isNotEmpty
            ? '@$resolved'
            : '@${id.length > 8 ? id.substring(0, 8) : id}',
    };

    final base = preferredStyle ?? const TextStyle();
    final isBroadcast = kind == 'everyone' || kind == 'here';
    final tone = isBroadcast ? ZentraColors.warning : ZentraColors.primary;

    return Text.rich(
      TextSpan(
        text: label,
        style: base.copyWith(
          color: tone,
          fontWeight: FontWeight.w500,
          backgroundColor: tone.withValues(alpha: isBroadcast ? 0.18 : 0.15),
        ),
        recognizer: kind == 'user' ? recognizerFor(id) : null,
      ),
    );
  }
}

/// Highlights fenced code blocks. The fence language is picked off the code
/// element during the tree walk, which runs before the block's text is read.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder();

  String? _language;

  @override
  void visitElementBefore(md.Element element) {
    md.Element? code;
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        code = child;
        break;
      }
    }
    _language = _languageOf(code);
  }

  @override
  Widget? visitText(md.Text textNode, TextStyle? preferredStyle) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.3,
            color: ZentraColors.textSecondary,
          ),
          children: _highlight(textNode.text, _language),
        ),
      ),
    );
  }

  static String? _languageOf(md.Element? code) {
    final classes = code?.attributes['class']?.split(' ') ?? const [];
    for (final value in classes) {
      if (value.startsWith('language-')) return value.substring(9);
    }
    return null;
  }

  static List<TextSpan> _highlight(String source, String? language) {
    try {
      final result = highlight.parse(
        source,
        language: language,
        autoDetection: language == null,
      );
      final spans = <TextSpan>[];
      _collect(result.nodes ?? const [], spans);
      if (spans.isEmpty) return [TextSpan(text: source)];
      return spans;
    } catch (_) {
      return [TextSpan(text: source)];
    }
  }

  static void _collect(List<Node> nodes, List<TextSpan> into) {
    for (final node in nodes) {
      final className = node.className;
      final value = node.value;
      if (value != null) {
        into.add(
          TextSpan(text: value, style: _syntaxTheme[className ?? '']),
        );
      } else {
        final children = <TextSpan>[];
        _collect(node.children ?? const [], children);
        into.add(
          TextSpan(children: children, style: _syntaxTheme[className ?? '']),
        );
      }
    }
  }
}

/// Token colours, matching the palette the web client maps highlight.js
/// classes onto.
final Map<String, TextStyle> _syntaxTheme = {
  'keyword': TextStyle(color: ZentraColors.primary),
  'selector-tag': TextStyle(color: ZentraColors.primary),
  'literal': TextStyle(color: ZentraColors.primary),
  'section': TextStyle(color: ZentraColors.primary),
  'string': TextStyle(color: ZentraColors.success),
  'symbol': TextStyle(color: ZentraColors.success),
  'bullet': TextStyle(color: ZentraColors.success),
  'template-variable': TextStyle(color: ZentraColors.success),
  'link': TextStyle(color: ZentraColors.success),
  'addition': TextStyle(color: ZentraColors.success),
  'number': TextStyle(color: ZentraColors.info),
  'type': TextStyle(color: ZentraColors.info),
  'built_in': TextStyle(color: ZentraColors.info),
  'class.title': TextStyle(color: ZentraColors.info),
  'attribute': TextStyle(color: ZentraColors.info),
  'selector-class': TextStyle(color: ZentraColors.info),
  'selector-attr': TextStyle(color: ZentraColors.info),
  'regexp': TextStyle(color: ZentraColors.info),
  'meta.string': TextStyle(color: ZentraColors.info),
  'title.function_': TextStyle(color: ZentraColors.warning),
  'title.function': TextStyle(color: ZentraColors.warning),
  'title': TextStyle(color: ZentraColors.warning),
  'function.title': TextStyle(color: ZentraColors.warning),
  'variable': TextStyle(color: ZentraColors.warning),
  'variable.language_': TextStyle(color: ZentraColors.warning),
  'meta': TextStyle(color: ZentraColors.secondary),
  'doctag': TextStyle(color: ZentraColors.secondary),
  'template-tag': TextStyle(color: ZentraColors.secondary),
  'attr': TextStyle(color: ZentraColors.secondary),
  'selector-id': TextStyle(color: ZentraColors.secondary),
  'selector-pseudo': TextStyle(color: ZentraColors.secondary),
  'property': TextStyle(color: ZentraColors.primaryHover),
  'params': TextStyle(color: ZentraColors.primaryHover),
  'punctuation': TextStyle(color: ZentraColors.primaryHover),
  'operator': TextStyle(color: ZentraColors.primaryHover),
  'subst': TextStyle(color: ZentraColors.primaryHover),
  'comment': TextStyle(color: ZentraColors.textMuted),
  'quote': TextStyle(color: ZentraColors.textMuted),
  'deletion': TextStyle(color: ZentraColors.danger),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.w700),
};

final MarkdownStyleSheet _styleSheet = MarkdownStyleSheet(
  p: TextStyle(fontSize: 15, height: 1.3, color: ZentraColors.textSecondary),
  pPadding: EdgeInsets.zero,
  a: TextStyle(
    color: ZentraColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: ZentraColors.primary,
  ),
  code: TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: ZentraColors.textPrimary,
    backgroundColor: ZentraColors.backgroundTertiary,
  ),
  codeblockPadding: EdgeInsets.all(12),
  codeblockDecoration: BoxDecoration(
    color: ZentraColors.backgroundSecondary,
    border: Border.fromBorderSide(BorderSide(color: ZentraColors.border)),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  ),
  h1: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textPrimary,
  ),
  h1Padding: EdgeInsets.only(top: 12, bottom: 8),
  h2: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textPrimary,
  ),
  h2Padding: EdgeInsets.only(top: 12, bottom: 8),
  h3: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textPrimary,
  ),
  h3Padding: EdgeInsets.only(top: 12, bottom: 8),
  h4: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textPrimary,
  ),
  h4Padding: EdgeInsets.only(top: 10, bottom: 6),
  h5: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textPrimary,
  ),
  h5Padding: EdgeInsets.only(top: 10, bottom: 6),
  h6: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: ZentraColors.textMuted,
  ),
  h6Padding: EdgeInsets.only(top: 10, bottom: 6),
  em: TextStyle(
    fontSize: 15,
    height: 1.3,
    fontStyle: FontStyle.italic,
    color: ZentraColors.textSecondary,
  ),
  strong: TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: ZentraColors.textSecondary,
  ),
  del: TextStyle(
    fontSize: 15,
    height: 1.3,
    decoration: TextDecoration.lineThrough,
    color: ZentraColors.textSecondary,
  ),
  blockquote: TextStyle(
    fontSize: 15,
    height: 1.3,
    color: ZentraColors.textMuted,
  ),
  blockquotePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  blockquoteDecoration: BoxDecoration(
    color: ZentraColors.backgroundSecondary,
    border: Border(
      left: BorderSide(color: ZentraColors.borderLight, width: 3),
    ),
    borderRadius: BorderRadius.all(Radius.circular(6)),
  ),
  listBullet: TextStyle(color: ZentraColors.textPrimary),
  listIndent: 24,
  listBulletPadding: EdgeInsets.zero,
  blockSpacing: 4,
  horizontalRuleDecoration: BoxDecoration(
    border: Border(top: BorderSide(color: ZentraColors.border)),
  ),
  img: TextStyle(fontStyle: FontStyle.italic),
  tableBorder: TableBorder(
    horizontalInside: BorderSide(color: ZentraColors.border),
    verticalInside: BorderSide(color: ZentraColors.border),
    bottom: BorderSide(color: ZentraColors.border),
  ),
  tableHead: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: ZentraColors.textPrimary,
  ),
  tableBody: TextStyle(fontSize: 13, color: ZentraColors.textSecondary),
  tableCellsPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  tablePadding: EdgeInsets.symmetric(vertical: 8),
);

/// Carries the mention resolvers down to the markdown builders, which only get
/// the parsed element and a build context.
class MentionScope extends InheritedWidget {
  const MentionScope({
    super.key,
    required this.userName,
    this.roleName,
    this.onMentionTap,
    required super.child,
  });

  final String? Function(String userId) userName;
  final String? Function(String roleId)? roleName;
  final void Function(String userId)? onMentionTap;

  static MentionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MentionScope>();

  @override
  bool updateShouldNotify(MentionScope oldWidget) =>
      userName != oldWidget.userName ||
      roleName != oldWidget.roleName ||
      onMentionTap != oldWidget.onMentionTap;
}