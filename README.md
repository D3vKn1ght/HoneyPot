# Hệ thống Honeypot – Triển khai và Ứng dụng trong 4 Tháng

## 1. Mục tiêu và Ứng dụng

### 1.1. Giám sát hành vi kẻ tấn công
- **Mục tiêu**: Thu thập thông tin kỹ thuật, công cụ, chiến thuật khai thác.
- **Honeypot**: Cowrie (SSH), Dionaea (SMB/FTP), Honeytrap (scan port)

### 1.2. Bẫy spam/botnet
- **Mục tiêu**: Phân tích spam, botnet.
- **Honeypot**: Mailoney (SMTP), HTTP Honeypot (Wordpot, Glastopf)

### 1.3. Cảnh báo sớm - Phòng thủ chủ động
- **Tích hợp**: Elastic & Logstash & Kibana

---

## 2. Kế hoạch Triển khai theo Tuần

### Tháng 1: Chuẩn bị và Thiết kế
- **Tuần 1**: Phân tích nhu cầu, chọn honeypot
  - Xác định các mục tiêu: SSH, SMB, HTTP, FTP, Mail, DB
  - Đề xuất honeypot:

    | Mục tiêu               | Honeypot đề xuất              | Chức năng chính |
    |------------------------|-------------------------------|------------------|
    | SSH Brute-force        | Cowrie                        | Mô phỏng SSH (và Telnet), ghi lại toàn bộ session của attacker (lệnh, file tải lên, password brute-force) |
    | SMB/FTP/RPC            | Dionaea                       | Bẫy dịch vụ Windows (SMB, FTP, RPC), thu thập mã độc và mẫu khai thác |
    | HTTP Web exploit       | Glastopf, Wordpot             | Mô phỏng trang web dễ bị tấn công để bắt các khai thác (LFI, RFI, SQLi) và botnet scanning |
    | Spam/Botnet            | Mailoney                      | Mô phỏng SMTP server, thu email spam, bot gửi email, phân tích chiến dịch spam |
    | Phát hiện quét port    | Honeytrap                     | Mở port ảo, phản hồi giả lập để phát hiện port scanning hoặc fingerprinting |

- **Tuần 2**: Thiết kế mô hình hệ thống
  - Phân chia các zone: Public, Email Trap, Logging
  - Thiết kế sơ đồ mạng và quy trình luồng dữ liệu từ honeypot đến hệ thống phân tích

- **Tuần 3**: Triển khai ELK stack ban đầu
  - Cài Logstash, Elasticsearch, Kibana trên máy trung tâm
  - Cấu hình pipeline log từ file hoặc Syslog

- **Tuần 4**: Backup & Unit test
  - Viết script backup log định kỳ (cron job)
  - Unit test từng honeypot: kiểm tra port, log, phản ứng khi bị scan

### Tháng 2: Deploy & Test
- **Tuần 5**: Triển khai honeypot ngoài public
  - Cowrie (port SSH), Dionaea (port SMB, FTP), Honeytrap (port scan)
  - Gán IP public / DNAT qua firewall/router

- **Tuần 6**: Phân tích hành vi, kịch bản tấn công thật
  - Sử dụng ELK để xem mẫu brute-force, port scan
  - Phân loại attacker theo IP, công cụ (masscan, hydra, etc.)

- **Tuần 7**: Tạo dashboard mẫu để hiển thị log Cowrie và Dionaea

- **Tuần 8**: Backup & Kiểm tra log hệ thống
  - Kiểm tra log đổ đúng index, đúng định dạng
  - So sánh dữ liệu từ honeypot và IDS/Firewall (nếu có)

### Tháng 3: Phân tích & Cảnh báo
- **Tuần 9**: Cài Mailoney, Glastopf; thu IP spam/bot
  - Kiểm tra các SMTP spam script, crawler HTTP độc hại
  - Ghi nhận User-Agent, IP và nội dung payload

- **Tuần 10**: Tích hợp cảnh báo và hoàn thiện dashboard
  - Gửi cảnh báo qua Telegram
  - Thiết kế dashboard phân theo khu vực, loại tấn công, CVE

- **Tuần 11**: Phân tích IOC và malware
  - Trích xuất mẫu từ Dionaea
  - Dùng VirusTotal để phân tích sâu (optional)

- **Tuần 12**: Cảnh báo real-time qua bot/email
  - Triển khai ELK Watcher
  - Tùy chọn block IP qua script hoặc firewall tự động

### Tháng 4: Đánh giá & Tối ưu
- **Tuần 13**: Viết báo cáo kỹ thuật
  - Tổng hợp log: attack timeline, IP, vector, payload
  - So sánh hành vi thực tế với mô hình phân tích đã thiết kế

- **Tuần 14**: Đánh giá hiệu suất honeypot
  - So sánh tài nguyên CPU/RAM từng honeypot
  - Kiểm tra độ ổn định và log trùng lặp

- **Tuần 15**: Retest toàn bộ hệ thống

- **Tuần 16**: Demo & đề xuất thực tế

---

## 3. Sơ đồ Hệ thống (gợi ý vẽ draw.io / diagrams.net)

- **Public Zone**: Cowrie, Dionaea, Glastopf
- **Email Trap Zone**: Mailoney, spam folder catcher
- **Logging & Alerting**: Filebeat/Logstash → ELK → Telegram

---

## 5. Tài nguyên Đề xuất

- https://github.com/mushorg/cowrie
- https://github.com/DinoTools/dionaea
- https://github.com/awhitehatter/mailoney
- https://www.honeynet.org/
- https://www.elastic.co/elk-stack
