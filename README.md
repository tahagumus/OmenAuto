# OmenAuto

Automatic performance and fan control for HP Victus / OMEN laptops on Windows — without opening OMEN Gaming Hub.

- **No game running:** Quiet mode, fans on auto, GPU at normal power.
- **Game running:** Performance mode and maximum GPU power (Custom TGP + AI Boost).
- **Smart fans in game:** when the GPU reaches 80 °C the fans go to full speed, and below 72 °C they go back to auto.
- Switches within about 5 seconds when a game opens or closes.
- **Status icon next to the clock:** blue = Quiet, red = Performance, grey = OmenAuto is not running. Hover over it to see the mode and the game.
- Runs completely hidden: no PowerShell window on the taskbar or in Alt+Tab.

OmenAuto talks to the laptop BIOS through Windows' own WMI interface (the same path OMEN Gaming Hub uses). It does **not** load any kernel driver, does not touch game memory, and does not draw on screen.

> ⚠️ **Use at your own risk.** This is an unofficial tool, not made or supported by HP. It was tested on one **HP Victus 16 (Thermal Policy Version 0)**. Other models may use different mode values. Anti-cheat systems decide for themselves what they allow; no guarantee can be given.

---

## Requirements

- Windows 10 / 11
- HP Victus or OMEN laptop with the HP WMI BIOS interface (`root\wmi : hpqBIntM`)
- An NVIDIA GPU (GPU temperature is read with `nvidia-smi`, which ships with the NVIDIA driver)
- Administrator rights (only once, for installation)

## Installation

1. Download or clone this repository into a folder you will keep, for example `C:\Users\<you>\OmenAuto`.
2. Double-click **`Kur.cmd`** and accept the administrator prompt.

`Kur.cmd` creates a Windows Task Scheduler task called **OmenAuto**. It starts hidden, with administrator rights, every time you sign in and every time the laptop wakes from sleep, so you will not see a UAC prompt on every boot. If it ever stops, Windows restarts it after one minute.

It also creates a second task called **OmenAutoTray**, which shows the status icon next to the clock. The icon runs without administrator rights because it only reads `OmenAuto.log`.

Both tasks start PowerShell through `conhost.exe --headless`, so no window appears. (On Windows 11, when Windows Terminal is the default terminal, the usual `-WindowStyle Hidden` option leaves an empty window in Alt+Tab.)

> Do not move the folder after installing. If you do, run `Kur.cmd` again.

## Files

| File | What it does |
|---|---|
| `OmenAuto.ps1` | The main script. Watches for games and sets the mode, GPU power and fans. |
| `OmenTray.ps1` | Status icon next to the clock. Only reads `OmenAuto.log`. |
| `HpBios.ps1` | Helper functions that send commands to the HP BIOS over WMI. |
| `Kur.cmd` / `Kur.ps1` | Installs OmenAuto (creates the two scheduled tasks). |
| `Kaldir.cmd` | Stops OmenAuto and the icon, and removes the scheduled tasks. |
| `Yeniden-Baslat.cmd` | Restarts OmenAuto after you change a setting. |
| `Durum.cmd` / `Durum.ps1` | Read-only sensor test. Writes temperatures, fan speeds and GPU power to `Durum.txt`. |

Everything OmenAuto does is written to `OmenAuto.log` in the same folder.

## Status icon

After installation a small dot appears next to the clock (if you don't see it, click the `^` arrow and drag it next to the clock):

| Colour | Meaning |
|---|---|
| Blue | Quiet mode (no game running) |
| Red | Performance mode (a game is running) |
| Grey | OmenAuto is not running, or the status is unknown |

Hover over the dot to see the mode, the game name and since when. Right-click it to open the log, restart OmenAuto or close the icon. Double-click opens the log.

The icon reads the last `Profil:` line in `OmenAuto.log` every 3 seconds. After a game opens, it can take about 10 seconds to turn red, because it shows the mode that has really been applied, not a guess.

## Settings

Open `OmenAuto.ps1` in a text editor. The settings are at the top:

| Setting | Default | Meaning |
|---|---|---|
| `$GameProcessNames` | VALORANT, League of Legends, CS2, … | Programs that count as games (`.exe` name without the extension). |
| `$GameFolderPatterns` | Steam, Epic, EA folders | Anything started from these folders counts as a game. |
| `$FanOnTemp` | `80` | GPU temperature (°C) at which fans go to full speed. |
| `$FanOffTemp` | `72` | GPU temperature (°C) at which fans go back to auto. |
| `$GpuMaxInGame` | `$true` | Give the GPU maximum power while gaming. |
| `$ModeValue` | Quiet = `3`, Performance = `1` | BIOS fan mode values. These were measured on a Victus 16; check yours first (see below). |

After changing anything, run **`Yeniden-Baslat.cmd`**.

### Checking the mode values on your laptop

The values above were measured on one laptop. On newer models (Thermal Policy Version 1) they may be different. Run `Durum.cmd` and look at the `Thermal Policy Version` line in `Durum.txt`. If it is not `0`, test carefully before relying on the default values.

## Uninstall

Double-click **`Kaldir.cmd`**, then delete the folder.

## Notes

- OMEN Gaming Hub's mode screen does **not** read the real BIOS mode. It only shows the last mode you picked inside the app, so it may say "Default" while OmenAuto has set Performance.
- If OMEN Gaming Hub or an HP service changes the mode, OmenAuto applies the right mode again within one minute. After waking from sleep it applies it immediately.
- The overhead is very small: one process list check every 5 seconds and one `nvidia-smi` call while gaming.

## Credits & license

The BIOS command codes in `HpBios.ps1` come from [OmenMon](https://omenmon.github.io/) by Piotr Szczepański (GPL-3.0). This project is released under the **GNU General Public License v3.0** — see [LICENSE](LICENSE).

---
---

# OmenAuto (Türkçe)

HP Victus / OMEN laptoplar için Windows'ta otomatik performans ve fan kontrolü. OMEN Gaming Hub'ı açmaya gerek kalmadan çalışır.

- **Oyun yokken:** Quiet modu, fanlar otomatik, ekran kartı normal güçte.
- **Oyun açıkken:** Performance modu ve ekran kartı maksimum güçte (Custom TGP + AI Boost).
- **Oyunda akıllı fan:** Ekran kartı 80 °C'ye ulaşınca fanlar tam hıza çıkar, 72 °C'nin altına inince otomatiğe döner.
- Oyun açılınca ya da kapanınca yaklaşık 5 saniye içinde geçiş yapar.
- **Saatin yanında durum simgesi:** mavi = Quiet, kırmızı = Performance, gri = OmenAuto çalışmıyor. Üstüne gelince mod ve oyun adı görünür.
- Tamamen gizli çalışır: görev çubuğunda ya da Alt+Tab'da PowerShell penceresi görünmez.

OmenAuto laptopun BIOS'una Windows'un kendi WMI arayüzüyle bağlanır (OMEN Gaming Hub'ın kullandığı yolun aynısı). Çekirdek sürücüsü **yüklemez**, oyunun belleğine dokunmaz ve ekrana bir şey çizmez.

> ⚠️ **Kullanım riski sana aittir.** Bu resmi olmayan bir araçtır, HP tarafından yapılmamıştır ve desteklenmez. Sadece bir **HP Victus 16 (Thermal Policy Version 0)** üzerinde test edildi. Başka modeller farklı mod değerleri kullanabilir. Anti-cheat sistemlerinin neye izin verdiğine kendileri karar verir, bu konuda garanti verilemez.

---

## Gereksinimler

- Windows 10 / 11
- HP WMI BIOS arayüzüne (`root\wmi : hpqBIntM`) sahip bir HP Victus ya da OMEN laptop
- NVIDIA ekran kartı (sıcaklık, NVIDIA sürücüsüyle gelen `nvidia-smi` ile okunur)
- Yönetici yetkisi (sadece kurulumda bir kez)

## Kurulum

1. Bu depoyu kalıcı olarak tutacağın bir klasöre indir ya da klonla, örneğin `C:\Users\<kullanıcı>\OmenAuto`.
2. **`Kur.cmd`**'ye çift tıkla ve yönetici izni penceresinde **Evet** de.

`Kur.cmd`, Windows Görev Zamanlayıcı'da **OmenAuto** adında bir görev oluşturur. Bu görev her oturum açışında ve laptop uykudan her uyandığında gizli olarak ve yönetici yetkisiyle başlar. Böylece her açılışta izin penceresi görmezsin. Bir sebeple durursa Windows onu bir dakika sonra yeniden başlatır.

Ayrıca saatin yanındaki durum simgesini gösteren **OmenAutoTray** adında ikinci bir görev oluşturur. Simge sadece `OmenAuto.log` dosyasını okuduğu için yönetici yetkisi olmadan çalışır.

İki görev de PowerShell'i `conhost.exe --headless` ile başlatır, bu yüzden hiç pencere açılmaz. (Windows 11'de varsayılan terminal Windows Terminal olduğunda, bilinen `-WindowStyle Hidden` ayarı Alt+Tab'da boş bir pencere bırakır.)

> Kurulumdan sonra klasörü taşıma. Taşırsan `Kur.cmd`'yi yeniden çalıştır.

## Dosyalar

| Dosya | Ne yapar |
|---|---|
| `OmenAuto.ps1` | Ana betik. Oyunları izler, modu, ekran kartı gücünü ve fanları ayarlar. |
| `OmenTray.ps1` | Saatin yanındaki durum simgesi. Sadece `OmenAuto.log` dosyasını okur. |
| `HpBios.ps1` | HP BIOS'una WMI üzerinden komut gönderen yardımcı fonksiyonlar. |
| `Kur.cmd` / `Kur.ps1` | OmenAuto'yu kurar (iki zamanlanmış görevi oluşturur). |
| `Kaldir.cmd` | OmenAuto'yu ve simgeyi durdurur, zamanlanmış görevleri siler. |
| `Yeniden-Baslat.cmd` | Bir ayarı değiştirdikten sonra OmenAuto'yu yeniden başlatır. |
| `Durum.cmd` / `Durum.ps1` | Sadece okuma yapan sensör testi. Sıcaklıkları, fan hızlarını ve ekran kartı gücünü `Durum.txt`'ye yazar. |

OmenAuto'nun yaptığı her şey aynı klasördeki `OmenAuto.log` dosyasına yazılır.

## Durum simgesi

Kurulumdan sonra saatin yanında küçük bir nokta çıkar (görmüyorsan `^` okuna tıkla ve noktayı saatin yanına sürükle):

| Renk | Anlamı |
|---|---|
| Mavi | Quiet modu (oyun yok) |
| Kırmızı | Performance modu (oyun açık) |
| Gri | OmenAuto çalışmıyor ya da durum bilinmiyor |

Noktanın üstüne gelince mod, oyunun adı ve hangi saatten beri o modda olduğu görünür. Sağ tıklayınca günlüğü açabilir, OmenAuto'yu yeniden başlatabilir ya da simgeyi kapatabilirsin. Çift tıklama günlüğü açar.

Simge her 3 saniyede bir `OmenAuto.log` içindeki son `Profil:` satırını okur. Oyun açıldıktan sonra kırmızıya dönmesi 10 saniye kadar sürebilir, çünkü tahmin değil, gerçekten uygulanmış modu gösterir.

## Ayarlar

`OmenAuto.ps1`'i bir metin düzenleyiciyle aç. Ayarlar en üstte:

| Ayar | Varsayılan | Anlamı |
|---|---|---|
| `$GameProcessNames` | VALORANT, League of Legends, CS2, … | Oyun sayılan programlar (uzantısız `.exe` adı). |
| `$GameFolderPatterns` | Steam, Epic, EA klasörleri | Bu klasörlerden açılan her şey oyun sayılır. |
| `$FanOnTemp` | `80` | Fanların tam hıza çıktığı ekran kartı sıcaklığı (°C). |
| `$FanOffTemp` | `72` | Fanların otomatiğe döndüğü ekran kartı sıcaklığı (°C). |
| `$GpuMaxInGame` | `$true` | Oyunda ekran kartına maksimum güç verilsin mi. |
| `$ModeValue` | Quiet = `3`, Performance = `1` | BIOS fan modu değerleri. Bir Victus 16'da ölçüldü, kendi laptopunda önce kontrol et (aşağıya bak). |

Bir şeyi değiştirdikten sonra **`Yeniden-Baslat.cmd`**'yi çalıştır.

### Kendi laptopunda mod değerlerini kontrol etme

Yukarıdaki değerler tek bir laptopta ölçüldü. Yeni modellerde (Thermal Policy Version 1) farklı olabilirler. `Durum.cmd`'yi çalıştır ve `Durum.txt`'deki `Thermal Policy Version` satırına bak. `0` değilse, varsayılan değerlere güvenmeden önce dikkatlice test et.

## Kaldırma

**`Kaldir.cmd`**'ye çift tıkla, sonra klasörü sil.

## Notlar

- OMEN Gaming Hub'daki mod ekranı BIOS'taki gerçek modu **okumaz**. Sadece uygulamanın içinde en son seçtiğin modu gösterir. Bu yüzden OmenAuto Performance'ı ayarlamışken orada "Default" yazabilir.
- OMEN Gaming Hub ya da bir HP servisi modu değiştirirse, OmenAuto bir dakika içinde doğru modu yeniden uygular. Uykudan uyanınca da hemen uygular.
- Sisteme yükü çok küçüktür: her 5 saniyede bir açık programlara bakar, oyun sırasında da bir kez `nvidia-smi` çağırır.

## Teşekkür ve lisans

`HpBios.ps1`'deki BIOS komut kodları, Piotr Szczepański'nin [OmenMon](https://omenmon.github.io/) projesinden (GPL-3.0) alınmıştır. Bu proje **GNU General Public License v3.0** ile yayınlanmıştır. Ayrıntılar için [LICENSE](LICENSE) dosyasına bak.
