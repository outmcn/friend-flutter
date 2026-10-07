part of 'main.dart';

class MyQrCodePage extends StatelessWidget {
  const MyQrCodePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('我的二维码')),
        body: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const Text(
              'DD 用户',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 22),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2, size: 190, color: Colors.black),
              ),
            ),
            const SizedBox(height: 18),
            const Text('扫一扫，添加我为好友', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.ios_share),
              label: const Text('保存或分享二维码'),
            ),
          ],
        ),
      );
}
