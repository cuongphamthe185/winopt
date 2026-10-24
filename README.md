# winopt

Script PowerShell giúp dọn giao diện Windows 10: ẩn thời tiết/news, các nút thừa trên taskbar, quảng cáo, gợi ý và kết quả Bing. Có sẵn sao lưu và khôi phục.

## Cách chạy
Mở PowerShell trong thư mục này. Không cần đổi ExecutionPolicy của máy, chỉ cần thêm `-ExecutionPolicy Bypass` khi chạy:

```
powershell -ExecutionPolicy Bypass -File .\winopt.ps1 <lệnh>
```

| Lệnh | Tác dụng |
|---|---|
| `list` | Liệt kê tất cả tweak |
| `status` | Trạng thái từng tweak: `applied` (đã áp dụng) / `partial` (một phần) / `default` (chưa áp dụng) |
| `apply basic -WhatIf` | Xem trước những gì sẽ đổi, không ghi gì |
| `apply basic` | Sao lưu rồi áp dụng preset `basic` |
| `apply full` | Như `basic`, thêm tắt hiệu ứng (transparency, Aero Peek, animation) |
| `apply full -Only taskbar-news,fx-aero-peek` | Chỉ áp dụng một vài tweak cụ thể |
| `restore` | Hoàn tác lần `apply` gần nhất; chạy tiếp lần nữa sẽ lùi thêm một bước |
| `restore -From backups\<file>.json` | Khôi phục theo một file sao lưu cụ thể |

Thêm `-NoRestart` nếu không muốn script tự khởi động lại Explorer.

## Lưu ý
- Hầu hết tweak chỉ áp dụng cho **user đang chạy script**. Mỗi user cần chạy riêng.
- Các tweak `taskbar-news`, `taskbar-meetnow`, `search-web-policy` cần quyền Admin (xem cột `Admin` khi chạy `list`). Chạy PowerShell bằng **Run as Administrator**, đăng nhập bằng chính tài khoản đó.
- Nhóm `effects` cần sign out rồi đăng nhập lại mới thấy đủ.
- File sao lưu nằm trong `backups/`, có chứa tên máy và tên user, nên đã được loại khỏi git.

## Thêm tweak
Thêm một mục vào `tweaks.json` (id, group, os, name, values). Nếu nhóm đã có trong preset thì tweak sẽ tự được áp dụng. Thử bằng `-WhatIf` trước.
