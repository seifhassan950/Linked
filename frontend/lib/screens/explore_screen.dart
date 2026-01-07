import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// ============================================================
// ✅ Explore Screen (WEB: Centered 3-col grid + RIGHT details panel)
// - Default: centered 3 columns
// - Click card: opens right panel (AssetDetailsPanel)
// - Close panel: back to centered grid
// ============================================================

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _webActiveNavIndex = 2;
  int? _webHoverNavIndex;

  String selectedCategory = "All";
  Map<String, String>? _selectedAsset;

  final List<String> _categories = const [
    "All",
    "Characters",
    "Objects",
    "Vehicles",
    "Environments",
    "Stylized",
    "Realistic",
  ];

  // ✅ EGP prices + FREE handling (price = 0)
  final List<Map<String, String>> _assets = const [
    {
      "name": "Cyberpunk Car",
      "author": "Studio Nova",
      "likes": "1.8k",
      "tag": "Vehicles",
      "style": "Stylized",
      "model": "assets/models/cyberpunk_car.glb",
      "poster": "assets/posters/cyberpunk_car.png",
      "description": "A sleek cyberpunk-style car with neon lights and futuristic design.",
      "price": "450",
      "currency": "EGP",
    },
    {
      "name": "Medieval Knight",
      "author": "PolyForge",
      "likes": "1.1k",
      "tag": "Characters",
      "style": "Realistic",
      "model": "assets/models/medieval_knight.glb",
      "poster": "assets/posters/medieval_knight.png",
      "description": "A detailed medieval knight character model in full armor.",
      "price": "0",
      "currency": "EGP",
    },
    {
      "name": "Sci-Fi Corridor",
      "author": "NeonLab",
      "likes": "980",
      "tag": "Environments",
      "style": "Stylized",
      "model": "assets/models/scifi_corridor.glb",
      "poster": "assets/posters/scifi_corridor.png",
      "description": "A futuristic sci-fi corridor environment with glowing panels.",
      "price": "799",
      "currency": "EGP",
    },
    {
      "name": "Stylized Trees",
      "author": "VoxelArt",
      "likes": "760",
      "tag": "Objects",
      "style": "Stylized",
      "model": "assets/models/stylized_trees.glb",
      "poster": "assets/posters/stylized_trees.png",
      "description": "A collection of stylized tree models perfect for game environments.",
      "price": "120",
      "currency": "EGP",
    },
    {
      "name": "Sports Sneaker",
      "author": "Meshcraft",
      "likes": "640",
      "tag": "Objects",
      "style": "Realistic",
      "model": "assets/models/sports_sneaker.glb",
      "poster": "assets/posters/sports_sneaker.png",
      "description": "A high-detail 3D model of a modern sports sneaker.",
      "price": "0.00",
      "currency": "EGP",
    },
    {
      "name": "Sci-Fi Drone",
      "author": "Zer0-G",
      "likes": "840",
      "tag": "Vehicles",
      "style": "Stylized",
      "model": "assets/models/scifi_drone.glb",
      "poster": "assets/posters/scifi_drone.png",
      "description": "A sleek sci-fi drone with futuristic design elements.",
      "price": "350",
      "currency": "EGP",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    return Stack(
      children: [
        const Positioned.fill(child: NebulaMeshBackground()),
        Positioned.fill(
          child: isWeb ? _buildWebMarketplace(context) : _buildMobileMarketplace(context),
        ),
      ],
    );
  }

  // =====================================================================
  // 🖥 WEB (Centered content + right details when selected)
  // =====================================================================

  Widget _buildWebMarketplace(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double contentWidth = w > 1180 ? 1180 : w;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHomeStyleTopBar(context),
              const SizedBox(height: 18),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: marketplace content (always centered)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMarketHeaderWithCgi(context),
                            const SizedBox(height: 18),
                            _buildSearchBar(),
                            const SizedBox(height: 16),
                            _buildWebCategoryChips(),
                            const SizedBox(height: 22),
                            const Text(
                              "Trending Today",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ✅ Centered 3 columns
                            _buildCenteredGrid3Cols(context),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT: details panel only when selected
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _selectedAsset == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: const ValueKey("rightPanel"),
                              padding: const EdgeInsets.only(top: 22, right: 16, bottom: 32),
                              child: SizedBox(
                                width: 360,
                                child: AssetDetailsPanel(
                                  asset: _selectedAsset!,
                                  onClose: () => setState(() => _selectedAsset = null),
                                  onFreeDownload: (asset) => _startDownload(context, asset),
                                  onPaidBuy: (asset) => Navigator.pushNamed(
                                    context,
                                    '/payment',
                                    arguments: asset,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredGrid3Cols(BuildContext context) {
    final items = _filteredAssets();
    const gap = 14.0;

    return LayoutBuilder(
      builder: (context, c) {
        final available = c.maxWidth;

        // ✅ Always 3 columns on web
        const cols = 3;

        final cardW = (available - (gap * (cols - 1))) / cols;

        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items.map((item) {
              return SizedBox(
                width: cardW,
                child: AssetCard(
                  name: item["name"]!,
                  author: item["author"]!,
                  likes: item["likes"]!,
                  tag: item["tag"]!,
                  styleTag: item["style"]!,
                  poster: item["poster"]!,
                  priceText: priceLabelEGP(item),
                  width: cardW,
                  onTap: () => setState(() => _selectedAsset = item),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 📱 MOBILE
  // =====================================================================

  Widget _buildMobileMarketplace(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Marketplace", style: TextStyle(fontWeight: FontWeight.w600,color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildMobileCategoryChips(),
            const SizedBox(height: 18),
            const Text(
              "Trending Today",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Column(
              children: _filteredAssets().map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AssetCard(
                    name: item["name"]!,
                    author: item["author"]!,
                    likes: item["likes"]!,
                    tag: item["tag"]!,
                    styleTag: item["style"]!,
                    poster: item["poster"]!,
                    priceText: priceLabelEGP(item),
                    width: double.infinity,
                    onTap: () => _openMobileDetails(item),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openMobileDetails(Map<String, String> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: AssetDetailsPanel(
            asset: item,
            onClose: () => Navigator.pop(context),
            onFreeDownload: (asset) => _startDownload(context, asset),
            onPaidBuy: (asset) => Navigator.pushNamed(
              context,
              '/payment',
              arguments: asset,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // UI helpers
  // =====================================================================

  Widget _buildHomeStyleTopBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 26, color: Color(0xFFBC70FF)),
              const SizedBox(width: 8),
              const Text(
                "R2V Studio",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SizedBox(width: 380, child: _buildHomeStyleNavTabs(context)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeStyleNavTabs(BuildContext context) {
    final labels = ["Home", "AI Studio", "Marketplace", "Settings"];
    final navCount = labels.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final segmentWidth = totalWidth / navCount;
        const indicatorWidth = 48.0;

        final underlineIndex = (_webHoverNavIndex ?? _webActiveNavIndex).clamp(0, navCount - 1);
        final underlineLeft = underlineIndex * segmentWidth + (segmentWidth - indicatorWidth) / 2;

        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Row(
                children: List.generate(navCount, (index) {
                  final isActive = _webActiveNavIndex == index;
                  final isHover = _webHoverNavIndex == index;
                  final effectiveActive = isActive || isHover;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _webHoverNavIndex = index),
                    onExit: (_) => setState(() => _webHoverNavIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _webActiveNavIndex = index);
                        switch (index) {
                          case 0:
                            Navigator.pushNamed(context, '/home');
                            break;
                          case 1:
                            Navigator.pushNamed(context, '/aichat');
                            break;
                          case 2:
                            break;
                          case 3:
                            Navigator.pushNamed(context, '/settings');
                            break;
                        }
                      },
                      child: SizedBox(
                        width: segmentWidth,
                        child: Center(
                          child: NavTextButton(label: labels[index], isActive: effectiveActive),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: underlineLeft,
                bottom: 0,
                child: Container(
                  width: indicatorWidth,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBC70FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketHeaderWithCgi(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.20),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Marketplace",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                "Browse trending 3D assets and CGI-ready packs. Mix, match, and export fast.",
                style: TextStyle(color: Colors.white70, height: 1.35, fontSize: 14.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebCategoryChips() {
    return Row(
      children: _categories.map((c) {
        final active = c == selectedCategory;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => selectedCategory = c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: active ? const LinearGradient(colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)]) : null,
                color: active ? null : Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Text(
                c,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((c) {
          final active = c == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: active ? const LinearGradient(colors: [Color(0xFF8A4FFF), Color(0xFFBC70FF)]) : null,
                  color: active ? null : Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Search 3D assets, creators, packs...",
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _filteredAssets() {
    if (selectedCategory == "All") return _assets;
    return _assets.where((a) => a["tag"] == selectedCategory || a["style"] == selectedCategory).toList();
  }

  // ============================================================
  // ✅ FREE + EGP price formatting
  // ============================================================

  static bool isFree(Map<String, String> asset) {
    final raw = (asset["price"] ?? "0").trim();
    final p = double.tryParse(raw) ?? 0.0;
    return p <= 0.0;
  }

  static String priceLabelEGP(Map<String, String> asset) {
    final raw = (asset["price"] ?? "0").trim();
    final p = double.tryParse(raw) ?? 0.0;
    if (p <= 0.0) return "FREE";
    final asInt = p == p.roundToDouble();
    return asInt ? "EGP ${p.toInt()}" : "EGP ${p.toStringAsFixed(2)}";
  }

  void _startDownload(BuildContext context, Map<String, String> asset) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Starting download: ${asset["name"] ?? ""}"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// =====================================================================
// ✅ Card (shows priceText: FREE or EGP xxx)
// =====================================================================

class AssetCard extends StatelessWidget {
  final String name;
  final String author;
  final String likes;
  final String tag;
  final String styleTag;
  final String poster;
  final String priceText;
  final double width;
  final VoidCallback? onTap;

  const AssetCard({
    super.key,
    required this.name,
    required this.author,
    required this.likes,
    required this.tag,
    required this.styleTag,
    required this.poster,
    required this.priceText,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCgiLike = styleTag == "Realistic" || tag == "Environments";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  poster,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withOpacity(0.06),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_rounded, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                MiniBadge(
                  text: isCgiLike ? "CGI" : styleTag,
                  accent: isCgiLike ? const Color(0xFF4CC9F0) : const Color(0xFFBC70FF),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text("by $author", style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const Spacer(),
                Text(
                  priceText,
                  style: TextStyle(
                    color: priceText == "FREE" ? const Color(0xFF22C55E) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.favorite_border_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(likes, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ✅ Details Panel (UNCHANGED logic)
// - Buy -> /payment route
// - Free -> start download
// - Expanded viewer fix (single WebGL)
// =====================================================================

class AssetDetailsPanel extends StatefulWidget {
  final Map<String, String> asset;
  final VoidCallback onClose;

  final void Function(Map<String, String> asset) onPaidBuy;
  final void Function(Map<String, String> asset) onFreeDownload;

  const AssetDetailsPanel({
    super.key,
    required this.asset,
    required this.onClose,
    required this.onPaidBuy,
    required this.onFreeDownload,
  });

  @override
  State<AssetDetailsPanel> createState() => _AssetDetailsPanelState();
}

class _AssetDetailsPanelState extends State<AssetDetailsPanel> {
  bool _expandedOpen = false;

  Future<void> _openExpanded(BuildContext context) async {
    setState(() => _expandedOpen = true);

    final model = widget.asset["model"] ?? "";
    final poster = widget.asset["poster"] ?? "";
    final title = widget.asset["name"] ?? "Preview";
    final bool isWebWide = MediaQuery.of(context).size.width >= 900;

    if (isWebWide) {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _ExpandedViewerShell(title: title, model: model, poster: poster),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.90,
            child: _ExpandedViewerShell(title: title, model: model, poster: poster),
          ),
        ),
      );
    }

    if (mounted) setState(() => _expandedOpen = false);
  }

  bool _isFree() {
    final raw = (widget.asset["price"] ?? "0").trim();
    final p = double.tryParse(raw) ?? 0.0;
    return p <= 0.0;
  }

  String _priceLabel() {
    final raw = (widget.asset["price"] ?? "0").trim();
    final p = double.tryParse(raw) ?? 0.0;
    if (p <= 0.0) return "FREE";
    final asInt = p == p.roundToDouble();
    return asInt ? "EGP ${p.toInt()}" : "EGP ${p.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.asset["name"] ?? "";
    final author = widget.asset["author"] ?? "";
    final likes = widget.asset["likes"] ?? "";
    final tag = widget.asset["tag"] ?? "";
    final style = widget.asset["style"] ?? "";
    final model = widget.asset["model"] ?? "";
    final poster = widget.asset["poster"] ?? "";
    final description = widget.asset["description"] ?? "No description provided.";

    final free = _isFree();
    final priceText = _priceLabel();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.close, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("by $author", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          MiniBadge(text: tag, accent: const Color(0xFF4CC9F0)),
                          MiniBadge(text: style, accent: const Color(0xFFBC70FF)),
                          MiniBadge(text: "Likes: $likes", accent: const Color(0xFFF72585)),
                          MiniBadge(
                            text: priceText,
                            accent: free ? const Color(0xFF22C55E) : const Color(0xFF8A4FFF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 11,
                              child: Container(
                                color: Colors.black.withOpacity(0.18),
                                child: _expandedOpen
                                    ? Image.asset(
                                        poster,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Icon(Icons.image, color: Colors.white.withOpacity(0.35)),
                                        ),
                                      )
                                    : ModelViewer(
                                        key: ValueKey(model),
                                        src: model,
                                        poster: poster,
                                        backgroundColor: Colors.transparent,
                                        cameraControls: true,
                                        disableZoom: true,
                                        autoRotate: true,
                                        environmentImage: "neutral",
                                        exposure: 1.0,
                                        shadowIntensity: 0.8,
                                        shadowSoftness: 1,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () => _openExpanded(context),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                                  ),
                                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(
                        "Pack Options",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _optionRow("Base Model", true),
                      _optionRow("LOD", false),
                      _optionRow("PBR Materials", true),

                      const SizedBox(height: 14),
                      Text(
                        "Formats",
                        style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [".obj", ".fbx", ".glb", ".usdz", ".stl"]
                            .map((f) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                                  ),
                                  child: Text(
                                    f,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text("Send"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (free) {
                          widget.onFreeDownload(widget.asset);
                        } else {
                          widget.onPaidBuy(widget.asset);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: free ? const Color(0xFF22C55E) : const Color(0xFF8A4FFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        free ? "Download" : "Buy $priceText",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _optionRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: enabled ? const Color(0xFF4CC9F0) : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ✅ Expanded viewer
// =====================================================================

class _ExpandedViewerShell extends StatelessWidget {
  final String title;
  final String model;
  final String poster;

  const _ExpandedViewerShell({
    required this.title,
    required this.model,
    required this.poster,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.close, size: 18, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    color: Colors.black.withOpacity(0.18),
                    child: ModelViewer(
                      key: ValueKey("expanded-$model"),
                      src: model,
                      poster: poster,
                      backgroundColor: Colors.transparent,
                      cameraControls: true,
                      disableZoom: false,
                      autoRotate: true,
                      environmentImage: "neutral",
                      exposure: 1.0,
                      shadowIntensity: 0.8,
                      shadowSoftness: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================

class NavTextButton extends StatelessWidget {
  final String label;
  final bool isActive;

  const NavTextButton({super.key, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 120),
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13.5,
      ),
      child: Text(label),
    );
  }
}

class MiniBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const MiniBadge({super.key, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.40)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// =====================================================================
// ✅ Background (unchanged)
// =====================================================================

class NebulaMeshBackground extends StatefulWidget {
  const NebulaMeshBackground({super.key});

  @override
  State<NebulaMeshBackground> createState() => _NebulaMeshBackgroundState();
}

class _NebulaMeshBackgroundState extends State<NebulaMeshBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Random _rng = Random(42);

  Size _size = Size.zero;
  Offset _mouse = Offset.zero;
  bool _hasMouse = false;

  late List<_NebulaParticle> _ps;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ps = <_NebulaParticle>[];
    _ticker = createTicker((elapsed) {
      _t = elapsed.inMilliseconds / 1000.0;
      if (!mounted) return;
      if (_size == Size.zero) return;

      const dt = 1 / 60;
      for (final p in _ps) {
        p.pos = p.pos + p.vel * dt;
        if (p.pos.dx < 0 || p.pos.dx > _size.width) p.vel = Offset(-p.vel.dx, p.vel.dy);
        if (p.pos.dy < 0 || p.pos.dy > _size.height) p.vel = Offset(p.vel.dx, -p.vel.dy);
        p.pos = Offset(p.pos.dx.clamp(0.0, _size.width), p.pos.dy.clamp(0.0, _size.height));
      }
      setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureParticles(Size s) {
    if (s == Size.zero) return;

    final area = s.width * s.height;
    int target = (area / 18000).round();
    target = target.clamp(35, 95);

    if (_ps.length == target) return;

    _ps = List.generate(target, (i) {
      final pos = Offset(_rng.nextDouble() * s.width, _rng.nextDouble() * s.height);
      final speed = 8 + _rng.nextDouble() * 18;
      final ang = _rng.nextDouble() * pi * 2;
      final vel = Offset(cos(ang), sin(ang)) * speed;
      final r = 1.2 + _rng.nextDouble() * 1.9;
      return _NebulaParticle(pos: pos, vel: vel, radius: r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = Size(c.maxWidth, c.maxHeight);
      if (_size != s) {
        _size = s;
        _ensureParticles(s);
      }

      return MouseRegion(
        onHover: (e) {
          _hasMouse = true;
          _mouse = e.localPosition;
        },
        onExit: (_) => _hasMouse = false,
        child: CustomPaint(
          painter: _NebulaPainter(
            particles: _ps,
            time: _t,
            size: s,
            mouse: _mouse,
            hasMouse: _hasMouse,
          ),
        ),
      );
    });
  }
}

class _NebulaParticle {
  Offset pos;
  Offset vel;
  final double radius;

  _NebulaParticle({required this.pos, required this.vel, required this.radius});
}

class _NebulaPainter extends CustomPainter {
  final List<_NebulaParticle> particles;
  final double time;
  final Size size;
  final Offset mouse;
  final bool hasMouse;

  _NebulaPainter({
    required this.particles,
    required this.time,
    required this.size,
    required this.mouse,
    required this.hasMouse,
  });

  @override
  void paint(Canvas canvas, Size _) {
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F1118), Color(0xFF141625), Color(0xFF0B0D14)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    void glowBlob(Offset c, double r, Color col, double a) {
      final p = Paint()
        ..color = col.withOpacity(a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
      canvas.drawCircle(c, r, p);
    }

    final center = Offset(size.width * 0.55, size.height * 0.35);
    final wobble = Offset(sin(time * 0.5) * 40, cos(time * 0.45) * 30);

    glowBlob(center + wobble, 280, const Color(0xFF8A4FFF), 0.18);
    glowBlob(
      Offset(size.width * 0.25, size.height * 0.70) + Offset(cos(time * 0.35) * 35, sin(time * 0.32) * 28),
      240,
      const Color(0xFF4895EF),
      0.14,
    );

    Offset parallax = Offset.zero;
    if (hasMouse) {
      final dx = (mouse.dx / max(1.0, size.width) - 0.5) * 18;
      final dy = (mouse.dy / max(1.0, size.height) - 0.5) * 18;
      parallax = Offset(dx, dy);
    }

    final connectDist = min(size.width, size.height) * 0.15;
    final connectDist2 = connectDist * connectDist;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < particles.length; i++) {
      final a = particles[i];
      final ap = a.pos + parallax * 0.25;

      for (int j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final bp = b.pos + parallax * 0.25;

        final dx = ap.dx - bp.dx;
        final dy = ap.dy - bp.dy;
        final d2 = dx * dx + dy * dy;

        if (d2 < connectDist2) {
          final t = 1.0 - (sqrt(d2) / connectDist);
          linePaint.color = Colors.white.withOpacity(0.06 * t);
          canvas.drawLine(ap, bp, linePaint);
        }
      }
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final pos = p.pos + parallax * 0.6;
      dotPaint.color = Colors.white.withOpacity(0.12);
      canvas.drawCircle(pos, p.radius, dotPaint);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.15,
        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => true;
}

