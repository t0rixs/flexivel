import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// 場所名入力用のオートコンプリートフィールド
/// 入力中に Places API で候補を取得し、選択式で確定する。
class PlaceAutocompleteField extends StatefulWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.apiService,
    this.hintText = '場所名',
    this.decoration,
    this.lat,
    this.lng,
    this.onSelected,
  });

  final TextEditingController controller;
  final ApiService apiService;
  final String hintText;
  final InputDecoration? decoration;
  final double? lat;
  final double? lng;
  final void Function(PlaceAutocompletePrediction)? onSelected;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<PlaceAutocompletePrediction> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _fetchSuggestions(widget.controller.text);
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    } else if (widget.controller.text.trim().length >= 2) {
      _fetchSuggestions(widget.controller.text);
    }
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _updateOverlay();
      return;
    }

    setState(() => _isLoading = true);
    _updateOverlay();

    try {
      final list = await widget.apiService.placesAutocomplete(
        input,
        lat: widget.lat,
        lng: widget.lng,
      );
      if (mounted) {
        setState(() {
          _suggestions = list;
          _isLoading = false;
        });
        _updateOverlay();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        _updateOverlay();
      }
    }
  }

  void _updateOverlay() {
    _removeOverlay();
    if (!mounted || !_focusNode.hasFocus) return;
    if (_suggestions.isEmpty && !_isLoading) return;

    final size = _getFieldSize();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text(
                            s.mainText,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: s.secondaryText.isNotEmpty
                              ? Text(
                                  s.secondaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          onTap: () => _select(s),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _select(PlaceAutocompletePrediction p) {
    widget.controller.text = p.fullText;
    widget.controller.selection = TextSelection.collapsed(offset: p.fullText.length);
    setState(() => _suggestions = []);
    _removeOverlay();
    _focusNode.unfocus(); // 候補選択後はフォーカスを外す
    widget.onSelected?.call(p);
  }

  Size _getFieldSize() {
    final r = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    return r?.size ?? const Size(200, 48);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        key: _fieldKey,
        child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixIcon: const Icon(Icons.place, size: 20),
            ),
        ),
      ),
    );
  }
}
