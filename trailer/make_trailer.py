#!/usr/bin/env python3
"""Records and edits the trailer of shots.json.

    make_trailer.py record [take ...]   each take (all without a name) in a headless gamescope:
                                        Godot's movie writer, an AVI of the frames and the mix
    make_trailer.py edit                the "sequence" of shots.json cut out of the recorded shots and
                                        joined, the end card added - into a new, numbered file
    make_trailer.py                     both

Everything lands in bin/trailer/ (not versioned). A take recorded again and the cut segments are
written over; a trailer never is - each edit writes the next maszyna-reloaded-trailer-NN.mp4 and
keeps the shots.json it was made from in trailer/history/ under the same name.
GODOT names the double precision Godot, as in the Makefile.

    TRAILER_SIZE=3840x2160    the frame (1920x1080 without it). Another size has its own takes and
                              segments, in bin/trailer/<height>p/, and its height in the trailer's
                              name (render_4k.sh)
    TRAILER_USED_ONLY=1       record without a take named: only the takes the sequence cuts from,
                              and of their shots only those - the others pass as empty frames,
                              and the take ends after its last filmed shot
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

TRAILER = Path(__file__).resolve().parent
SHOTS = TRAILER / "shots.json"
REPO = TRAILER.parent
OUT = REPO / "bin" / "trailer"
# Every edit is a new file: maszyna-reloaded-trailer.mp4 was the first, the next ones are numbered
RESULT_NAME = "maszyna-reloaded-trailer-{:02d}{}.mp4"
RESULT_NUMBER = re.compile(r"maszyna-reloaded-trailer-(\d+)(-\d+p)?\.mp4$")
FIRST_NUMBER = 2
# The shots.json each trailer was made from, under the trailer's name - to go back to
HISTORY = TRAILER / "history"
GODOT = os.environ.get("GODOT", "godot-double")
LOGO = REPO / "loading_screen" / "logo.png"

# The frame of the trailers so far, and this run's
DEFAULT_SIZE = "1920x1080"
WIDTH, HEIGHT = (int(side) for side in os.environ.get("TRAILER_SIZE", DEFAULT_SIZE).split("x"))
# Another size than the default's keeps its takes and segments apart, and says so in its name
SIZED = not f"{WIDTH}x{HEIGHT}" == DEFAULT_SIZE
WORK = OUT / f"{HEIGHT}p" if SIZED else OUT
RESULT_SIZE = f"-{HEIGHT}p" if SIZED else ""
USED_ONLY = os.environ.get("TRAILER_USED_ONLY", "") == "1"
FPS = 60
# Takes recorded side by side
TAKES_AT_ONCE = 4
AUDIO_RATE = 48000
# Godot's movie writer records at the project's viewport size, whatever the window's (measured:
# a 1920x1080 window gave 1152x648 frames), so project.godot has it for the recording only
PROJECT = REPO / "project.godot"
PROJECT_SECTION = "[display]\n"
PROJECT_SIZE = f"\nwindow/size/viewport_width={WIDTH}\nwindow/size/viewport_height={HEIGHT}\n"
# ...and the quality of the AVI's frames (MJPEG; PNG frames took 0.4 s each to write)
PROJECT_MOVIE = "\n[editor]\n\nmovie_writer/mjpeg_quality=0.95\n"
# The chunks of Godot's AVI (modules/jpg/movie_writer_mjpeg.cpp): a frame's picture, its sound,
# and the index that ends the film
CHUNK_PICTURE = b"00db"
CHUNK_INDEX = b"idx1"
CHUNK_HEAD = struct.Struct("<4sI")
# The sound's format in the AVI's header: after "strf" and its size, the second such chunk
SOUND_FORMAT = struct.Struct("<HHIIHH")
# Seconds of the fade from black at the film's start and at the end card's, picture and sound alike
FADE = 0.5
# Seconds the sound of a shot fades in and out at a hard cut, so the join does not click
CUT_FADE = 0.05
# Seconds of the end card - the loading screen's logo alone, in the middle - and the logo's width;
# shots.json's "card" gives another
CARD_SECONDS = 4.0
CARD_LOGO_WIDTH = round(760 * WIDTH / 1920)
# The director's line of a recorded shot (trailer_take.gd)
SHOT_LINE = re.compile(r"^\[Trailer\] (\S+) frames (\d+) (\d+)", re.MULTILINE)
VIDEO = ["-c:v", "libx264", "-crf", "18", "-preset", "slow", "-pix_fmt", "yuv420p",
         "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-r", str(FPS)]
AUDIO = ["-c:a", "pcm_s16le", "-ar", str(AUDIO_RATE), "-ac", "2"]
TO_BT709 = "scale=out_color_matrix=bt709:out_range=tv"
# The joined sound held under -1 dB true peak: a take's loudest moments (a cab's relays) go past
# 0 dB, with edges sharp enough to slip through ffmpeg's limiter at 48 kHz and to peak between the
# samples - so it limits four times oversampled, with a short attack, and without its delay, so the
# sound stays on the picture
LIMITER = "aresample=192000,alimiter=limit=0.8:level=0:latency=1:attack=1,aresample=48000"


def run(command, **kwargs):
    subprocess.run([str(part) for part in command], check=True, **kwargs)


def last_filmed_at(take, used):
    """The "at" a take's last filmed shot starts by: the latest one given up to that shot."""
    latest = 0.0
    filmed = 0.0
    for shot in take["shots"]:
        latest = shot.get("at", latest)
        if shot["name"] in used:
            filmed = latest
    return filmed


def record(shots_file, names):
    takes = shots_file["takes"]
    chosen = [take for take in takes if not names or take["name"] in names]
    # the shots the sequence cuts from; without a take named, only the takes that have one
    used = sorted({cut["shot"] for cut in shots_file["sequence"]}) if USED_ONLY else []
    if USED_ONLY and not names:
        chosen = [take for take in takes if any(shot["name"] in used for shot in take["shots"])]
    only = ["--only", ",".join(used)] if used else []
    # the long takes together: a batch lasts as long as its longest
    if used:
        chosen.sort(reverse=True, key=lambda take: last_filmed_at(take, used))
    project = PROJECT.read_text()
    PROJECT.write_text(project.replace(PROJECT_SECTION, PROJECT_SECTION + PROJECT_SIZE, 1) + PROJECT_MOVIE)
    # the takes side by side - a take is minutes of loading and of the simulation's own time -
    # but no more than TAKES_AT_ONCE: each is a whole game in memory
    running = []
    try:
        for start in range(0, len(chosen), TAKES_AT_ONCE):
            running = []
            for take in chosen[start:start + TAKES_AT_ONCE]:
                directory = WORK / take["name"]
                directory.mkdir(parents=True, exist_ok=True)
                for old in directory.glob("frame*"):
                    old.unlink()
                with open(directory / "take.out", "w") as output:
                    running.append(subprocess.Popen(
                        [str(part) for part in
                         ["gamescope", "--backend", "headless", "-W", WIDTH, "-H", HEIGHT,
                          "-w", WIDTH, "-h", HEIGHT, "-r", FPS, "--",
                          GODOT, "--path", REPO, "res://trailer/trailer_take.tscn",
                          "--display-driver", "x11", "--resolution", f"{WIDTH}x{HEIGHT}",
                          "--fixed-fps", FPS, "--write-movie", directory / "frame.avi",
                          "--log-file", directory / "godot.log", "--", "--take", take["name"], *only]],
                        stdout=output, stderr=subprocess.STDOUT))
            for process in running:
                process.wait()
    finally:
        for process in running:
            process.terminate()
        PROJECT.write_text(project)


def film_index(film):
    """Where each frame's picture and each frame's sound stand in a take's AVI, read chunk by chunk.

    Godot's writer keeps the file's sizes and its index in 32 bits: past 4 GB - a wait of nine
    minutes in 3840x2160, an empty frame is 130 kB - both are wrong, while the frames are all
    there. Returns the pictures and the sounds as (position, size), and the sound's rate, channels
    and bits.
    """
    pictures = []
    sounds = []
    with open(film, "rb") as file:
        head = file.read(4096)
        formats = head.index(b"strf", head.index(b"auds"))
        _, channels, rate, _, _, bits = SOUND_FORMAT.unpack_from(head, formats + CHUNK_HEAD.size)
        file.seek(head.index(b"movi") + 4)
        while True:
            chunk = file.read(CHUNK_HEAD.size)
            if len(chunk) < CHUNK_HEAD.size:
                break
            name, size = CHUNK_HEAD.unpack(chunk)
            if name == CHUNK_INDEX:
                break
            (pictures if name == CHUNK_PICTURE else sounds).append((file.tell(), size))
            # a picture of an odd size is followed by a byte of padding
            file.seek(size + (size & 1), os.SEEK_CUR)
    return pictures, sounds, (rate, channels, bits)


def copy_chunks(film, chunks, target):
    with open(film, "rb") as source, open(target, "wb") as output:
        for position, size in chunks:
            source.seek(position)
            output.write(source.read(size))


def next_result():
    """The trailer's file: numbered after the ones already there, which are never written over."""
    numbers = [int(match.group(1)) for match in map(RESULT_NUMBER.match, (path.name for path in OUT.iterdir()))
               if match]
    return OUT / RESULT_NAME.format(max(numbers, default=FIRST_NUMBER - 1) + 1, RESULT_SIZE)


def edit(shots_file):
    segments = WORK / "segments"
    segments.mkdir(parents=True, exist_ok=True)
    for old in segments.iterdir():
        old.unlink()
    # where each recorded shot starts in its take's film
    starts = {}
    for take in shots_file["takes"]:
        directory = WORK / take["name"]
        if not (directory / "take.out").exists():
            continue
        for name, first, last in SHOT_LINE.findall((directory / "take.out").read_text(errors="replace")):
            starts[name] = (directory / "frame.avi", int(first), int(last))
    indexes = {}
    picture = TO_BT709
    if "letterbox" in shots_file:
        # the bars of a wider frame, the picture between them untouched
        visible = round(WIDTH / shots_file["letterbox"] / 2) * 2
        bar = (HEIGHT - visible) // 2
        picture += (f",drawbox=x=0:y=0:w={WIDTH}:h={bar}:color=black:t=fill"
                    f",drawbox=x=0:y={HEIGHT - bar}:w={WIDTH}:h={bar}:color=black:t=fill")
    sequence = shots_file["sequence"]
    parts = []
    for index, cut in enumerate(sequence):
        film, first, last = starts[cut["shot"]]
        first += round(cut.get("from", 0.0) * FPS)
        count = min(round(cut["length"] * FPS), last - first) if "length" in cut else last - first
        seconds = count / FPS
        # a cut's "speed": slow motion below 1.0 - the frames held longer. The sound is not
        # stretched with them (a stretched rumble warbles): it is the shot's own, as long as the
        # slowed picture, from the same moment on
        speed = cut.get("speed", 1.0)
        shown = round(count / speed)
        video = f"setpts=PTS/{speed}," + picture
        fade_in, fade_out = CUT_FADE, CUT_FADE
        # the film opens from black; the cuts after are hard, the last one into the end card's black
        if index == 0:
            fade_in = FADE
            video += f",fade=in:0:{round(FADE * FPS)}"
        part = segments / f"{index:02d}_{cut['shot']}.mkv"
        # the cut's frames and sound taken out of the take's film by its chunks (film_index())
        if film not in indexes:
            indexes[film] = film_index(film)
        pictures, sounds, (rate, channels, bits) = indexes[film]
        cut_pictures = segments / "cut.mjpeg"
        cut_sound = segments / "cut.pcm"
        # a slowed cut ends on its last frame held: one frame more, or ffmpeg ends a frame short
        held = 1 if speed < 1.0 else 0
        copy_chunks(film, pictures[first:first + count + held], cut_pictures)
        copy_chunks(film, sounds[first:first + shown], cut_sound)
        run(["ffmpeg", "-v", "error", "-y",
             "-f", "mjpeg", "-framerate", FPS, "-i", cut_pictures,
             "-f", f"s{bits}le", "-ar", rate, "-ac", channels, "-i", cut_sound,
             "-map", "0:v", "-map", "1:a", "-frames:v", shown, "-vf", video,
             "-af", f"afade=in:st=0:d={fade_in},afade=out:st={shown / FPS - fade_out:.4f}:d={fade_out}",
             *VIDEO, *AUDIO, part])
        parts.append(part)
    cut_pictures.unlink()
    cut_sound.unlink()
    card_seconds = shots_file.get("card", CARD_SECONDS)
    card = segments / "card.png"
    run(["magick", "-size", f"{WIDTH}x{HEIGHT}", "xc:black",
         "(", LOGO, "-trim", "+repage", "-resize", f"{CARD_LOGO_WIDTH}x", ")",
         "-gravity", "center", "-composite", card])
    part = segments / f"{len(parts):02d}_card.mkv"
    run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-framerate", FPS, "-t", card_seconds, "-i", card,
         "-f", "lavfi", "-t", card_seconds, "-i", f"anullsrc=r={AUDIO_RATE}:cl=stereo",
         "-vf", f"{TO_BT709},fade=in:0:{round(FADE * FPS)}", *VIDEO, *AUDIO, part])
    parts.append(part)
    listing = segments / "parts.txt"
    listing.write_text("".join(f"file '{part}'\n" for part in parts))
    result = next_result()
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing,
         "-c:v", "copy", "-af", LIMITER, "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", result])
    HISTORY.mkdir(exist_ok=True)
    shutil.copyfile(SHOTS, HISTORY / f"{result.stem}.json")
    print(result)


def main():
    shots_file = json.loads(SHOTS.read_text())
    # bin/ is inside the project: without it Godot imports every recording as the game's resource
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").touch()
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command in ("", "record"):
        record(shots_file, sys.argv[2:])
    if command in ("", "edit"):
        edit(shots_file)


if __name__ == "__main__":
    main()
