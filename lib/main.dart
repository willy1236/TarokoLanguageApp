
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const KariTrukuApp());
}

class KariTrukuApp extends StatelessWidget {
  const KariTrukuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KARI TRUKU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        primaryColor: const Color(0xFFEA580C),
        fontFamily: 'Noto Sans TC',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEA580C),
          secondary: Color(0xFF1E293B),
          surface: Color(0xFF0F172A),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/': (_) => const MainContainer(),
      },
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  String _mediaView = 'list';
  String _communityView = 'list';
  bool _isForum = true;

  @override
  Widget build(BuildContext context) {
    bool isCommunity = _currentIndex == 3;
    bool isDetailsOrPublish = _communityView != 'list' && isCommunity;
    bool isPlayer = _mediaView == 'player' && _currentIndex == 2;
    bool showNavBar = !isDetailsOrPublish && !isPlayer;

    return Scaffold(
      extendBody: true,
      appBar: !showNavBar ? null : AppBar(
        backgroundColor: const Color(0xFF0F172A).withAlpha(204), // 0.8 opacity
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white70),
          onPressed: () {},
        ),
        title: const Column(
          children: [
            Text('KARI TRUKU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
            Text('太魯閣族語傳承', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(onNavigate: (i) => setState(() => _currentIndex = i)),
              const LearningScreen(),
              MediaScreen(
                view: _mediaView, 
                onPlay: () => setState(() => _mediaView = 'player'),
                onBack: () => setState(() => _mediaView = 'list')
              ),
              CommunityScreen(
                view: _communityView, 
                isForum: _isForum,
                onViewChange: (v) => setState(() => _communityView = v),
                onModeChange: (f) => setState(() => _isForum = f),
              ),
              const ProfileScreen(),
            ],
          ),
          
          if (_currentIndex == 3 && _communityView == 'list' && !_isForum)
            Positioned(
              bottom: 105,
              right: MediaQuery.of(context).size.width * 0.1 - 20,
              child: FloatingActionButton(
                onPressed: () => setState(() => _communityView = 'publish'),
                backgroundColor: const Color(0xFFEA580C),
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !showNavBar ? null : Container(
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withAlpha(242), // 0.95 opacity
          border: const Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
            _mediaView = 'list';
            _communityView = 'list';
          }),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFEA580C),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '首頁'),
            BottomNavigationBarItem(icon: Icon(Icons.book_rounded), label: '學習'),
            BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill), label: '影音'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: '社群'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: '會員'),
          ],
        ),
      ),
    );
  }
}

// --- 首頁 ---
class HomeScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://picsum.photos/id/64/100/100')),
                  const SizedBox(width: 15),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mhuway su!', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w900, fontSize: 12)),
                      Text('Kating, 歡迎學習', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('每日學習進度', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('85%', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(value: 0.85, minHeight: 6, backgroundColor: Colors.white10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text('族語學習路徑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.5,
          children: [
            _buildQuickCard('每日練習', Icons.book_rounded, const Color(0xFFFB7185)), // Fixed rose color
            _buildQuickCard('檢定衝刺', Icons.verified_rounded, Colors.indigoAccent),
          ],
        ),
        const SizedBox(height: 30),
        const Text('影音推薦', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            image: const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1544965850-6f8a66788f9b?w=800'), fit: BoxFit.cover),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), 
              gradient: LinearGradient(
                colors: [Colors.black.withAlpha(153), Colors.transparent], // 0.6 opacity
                begin: Alignment.bottomCenter, 
                end: Alignment.topCenter
              )
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomLeft,
            child: const Text('太魯閣族傳統織布工藝', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCard(String t, IconData i, Color c) {
    return Container(
      decoration: BoxDecoration(
        color: c.withAlpha(26), // ~0.1 opacity
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: c.withAlpha(51)) // ~0.2 opacity
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 28), const SizedBox(height: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
    );
  }
}

// --- 學習中心 ---
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('族語學習中心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
              child: const Icon(Icons.settings_outlined, color: Colors.grey, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
          child: Row(
            children: [
              _buildTab('日常練習', _activeTab == 0, () => setState(() => _activeTab = 0)),
              _buildTab('考試準備', _activeTab == 1, () => setState(() => _activeTab = 1)),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
          child: Column(children: [
            const Row(children: [Icon(Icons.stars, color: Colors.orange, size: 30), SizedBox(width: 12), Text('Truku 等級：初級', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 20),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('當前進度', style: TextStyle(fontSize: 12, color: Colors.grey)), Text('65%', style: TextStyle(fontSize: 12))]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: const LinearProgressIndicator(value: 0.65, minHeight: 8)),
          ]),
        ),
        const SizedBox(height: 30),
        const Text('學習路徑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildPathItem(Icons.book, '單字學習', Colors.blue),
            _buildPathItem(Icons.edit, '語法探究', Colors.purple),
            _buildPathItem(Icons.headset, '聽力測驗', Colors.orange),
            _buildPathItem(Icons.mic, '口說練習', Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildTab(String l, bool a, VoidCallback o) {
    return Expanded(
      child: GestureDetector(
        onTap: o,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: a ? const Color(0xFF1E293B) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(l, style: TextStyle(color: a ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14))),
        ),
      ),
    );
  }

  Widget _buildPathItem(IconData i, String t, Color c) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 32), const SizedBox(height: 12), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }
}

// --- 影音中心 ---
class MediaScreen extends StatelessWidget {
  final String view;
  final VoidCallback onPlay;
  final VoidCallback onBack;
  const MediaScreen({super.key, required this.view, required this.onPlay, required this.onBack});

  @override
  Widget build(BuildContext context) {
    if (view == 'player') return _buildPlayer(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: '搜尋影音資源...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 25),
        _buildMediaItem('The Art of Weaving', '太魯閣族傳統織布工藝紀錄', 'https://images.unsplash.com/photo-1544965850-6f8a66788f9b?w=800'),
        _buildMediaItem('Mgay Bari 感恩祭典', '祖靈文化傳承：祭儀與語言', 'https://picsum.photos/id/1015/600/400'),
      ],
    );
  }

  Widget _buildMediaItem(String t, String s, String i) {
    return InkWell(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(i, height: 200, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(s, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: onBack),
        title: const Text('影音播放中', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        AspectRatio(
          aspectRatio: 16/9,
          child: Container(
            color: const Color(0xFF0F172A),
            child: const Center(child: Icon(Icons.play_circle_fill, size: 80, color: Colors.white70)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('The Art of Weaving: Truku Traditions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('這部紀錄片深入探討了太魯閣族織布傳統的語言意義與文化圖騰。', style: TextStyle(color: Colors.grey[400], height: 1.6, fontSize: 14)),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _playerAction(Icons.favorite_border, 'LIKE'),
              _playerAction(Icons.share, 'SHARE'),
              _playerAction(Icons.download, 'SAVE'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _playerAction(IconData i, String l) {
    return Column(children: [Icon(i, color: Colors.white70), const SizedBox(height: 6), Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
  }
}

// --- 社群中心 ---
class CommunityScreen extends StatelessWidget {
  final String view;
  final bool isForum;
  final Function(String) onViewChange;
  final Function(bool) onModeChange;
  const CommunityScreen({super.key, required this.view, required this.isForum, required this.onViewChange, required this.onModeChange});

  @override
  Widget build(BuildContext context) {
    if (view == 'details') return _buildDetails(context);
    if (view == 'publish') return _buildPublish(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: '搜尋貼文...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _buildTab('論壇討論', isForum, () => onModeChange(true)),
            _buildTab('活動發布', !isForum, () => onModeChange(false)),
          ]),
        ),
        const SizedBox(height: 25),
        if (isForum) ...[
          _buildPost('Apyang Imiq', '如何有效地學習族語？', 'Kmtmangan! 我最近在練習動詞變化...', 'https://picsum.photos/id/11/400/250'),
          const SizedBox(height: 20),
          _buildPost('Suda Buyung', '分享這週的部落故事', '長輩跟我分享了關於獵人的古老傳說...', 'https://picsum.photos/id/12/400/250'),
        ] else ...[
          _buildEvent('Mgay Bari (感恩祭)', '2023年10月25日', '秀林鄉部落中心'),
        ],
      ],
    );
  }

  Widget _buildTab(String l, bool a, VoidCallback o) {
    return Expanded(
      child: GestureDetector(
        onTap: o,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: a ? const Color(0xFF1E293B) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(l, style: TextStyle(color: a ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
        ),
      ),
    );
  }

  Widget _buildPost(String a, String t, String c, String i) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(radius: 16), const SizedBox(width: 10), Text(a, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
        const SizedBox(height: 15),
        Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(c, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 15),
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(i, height: 180, width: double.infinity, fit: BoxFit.cover)),
      ]),
    );
  }

  Widget _buildEvent(String t, String d, String loc) {
    return InkWell(
      onTap: () => onViewChange('details'),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.withAlpha(51))), // ~0.2 opacity
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('# 祭典活動', style: TextStyle(color: Color(0xFFFB7185), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.grey), const SizedBox(width: 8), Text(d, style: const TextStyle(color: Colors.grey, fontSize: 12))]),
          const SizedBox(height: 20),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(26), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('立即報名參與', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)))),
        ]),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        SingleChildScrollView(child: Column(children: [
          Image.network('https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=800', height: 400, fit: BoxFit.cover, width: double.infinity),
          Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Mgay Bari (感恩祭)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('關於活動 Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Mgay Bari 是太魯閣族一年一度最重要的感恩祭典。我們聚在一起感謝祖靈 (Utux) 的庇佑。活動包含傳統祭儀、樂舞展演、及手工藝品展示。', style: TextStyle(color: Colors.grey, height: 1.6)),
            SizedBox(height: 120),
          ])),
        ])),
        Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.black45, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => onViewChange('list')))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), color: const Color(0xFF0F172A), child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('立即報名參與 Register Now', style: TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    );
  }

  Widget _buildPublish(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, leading: TextButton(onPressed: () => onViewChange('list'), child: const Text('取消', style: TextStyle(color: Colors.grey))), title: const Text('發布活動'), actions: [TextButton(onPressed: () => onViewChange('list'), child: const Text('發布', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)))]),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: const [
        TextField(decoration: InputDecoration(labelText: '活動標題 Subject', labelStyle: TextStyle(fontSize: 12))),
        SizedBox(height: 20),
        TextField(decoration: InputDecoration(labelText: '活動地點 Location', labelStyle: TextStyle(fontSize: 12))),
        SizedBox(height: 20),
        TextField(maxLines: 5, decoration: InputDecoration(labelText: '活動細節 Body Text', labelStyle: TextStyle(fontSize: 12), border: OutlineInputBorder())),
      ])),
    );
  }
}

// --- 個人中心 (1:1 還原截圖) ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        const Center(child: Column(children: [
          CircleAvatar(radius: 45, backgroundImage: NetworkImage('https://picsum.photos/id/64/200/200')),
          SizedBox(height: 15),
          Text('Apyang Imiq', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('LEVEL 2 • 太魯閣族語學習者', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ])),
        const SizedBox(height: 35),
        Row(children: [
          _buildStatBox('12', '連續學習', const Color(0xFFFB923C)),
          const SizedBox(width: 12),
          _buildStatBox('120', '已學單字', const Color(0xFF60A5FA)),
          const SizedBox(width: 12),
          _buildStatBox('05', '社群貢獻', const Color(0xFF4ADE80)),
        ]),
        const SizedBox(height: 35),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('學習紀錄 | LEARNING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
        ),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
          child: Column(children: [
            _buildMenuItem(Icons.access_time_filled_rounded, '我的學習進度', const Color(0xFF3B82F6)),
            _buildDivider(),
            _buildMenuItem(Icons.star_rounded, '我的收藏', const Color(0xFFF59E0B)),
            _buildDivider(),
            _buildMenuItem(Icons.military_tech_rounded, '我參與的活動', const Color(0xFFA855F7)),
            _buildDivider(),
            _buildMenuItem(Icons.settings_rounded, '帳號設定', Colors.grey[600]!),
            _buildDivider(),
              _buildLogoutItem(context),
          ]),
        ),
      ],
    );
  }

  Widget _buildStatBox(String v, String l, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(13)), // ~0.05 opacity
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 6),
          Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildMenuItem(IconData i, String l, Color ic) {
    return ListTile(
      leading: Icon(i, color: ic, size: 22),
      title: Text(l, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white12, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.logout_rounded,
        color: Color(0xFFEF4444),
        size: 22,
      ),
      title: const Text(
        '登出帳號 Logout',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFFEF4444),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.white.withAlpha(8), indent: 20, endIndent: 20);
  }
}
