# dmgbuild ayarları — Arşivci kurulum penceresi
# Kullanım: dmgbuild -s scripts/dmg-settings.py -D app=build/Arşivci.app -D background=build/background.tiff "Arşivci" build/Arsivci.dmg
# Finder'ı otomatikleştirmeden .DS_Store'u doğrudan yazar; GitHub Actions'ta güvenle çalışır.
import os.path

app = defines.get("app", "build/Arşivci.app")  # noqa: F821  (dmgbuild sağlar)
app_name = os.path.basename(app)

format = "UDZO"
compression_level = 9
filesystem = "HFS+"
size = None

files = [app]
symlinks = {"Uygulamalar": "/Applications"}

# Disk simgesi = uygulama logosu
badge_icon = None
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")

# Pencere görünümü (arka plan 660x400)
background = defines.get("background", "Resources/dmg-background.png")  # noqa: F821
window_rect = ((200, 120), (660, 422))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 128

icon_locations = {
    app_name: (165, 155),
    "Uygulamalar": (495, 155),
    # Gizli dosyaları göster açık olsa bile pencere dışında kalsınlar
    ".background": (1200, 1200),
    ".background.tiff": (1200, 1200),
    ".VolumeIcon.icns": (1300, 1200),
    ".fseventsd": (1400, 1200),
    ".Trashes": (1500, 1200),
}
