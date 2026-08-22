using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

// Replaced at build time from pubspec.yaml. The C# compiler turns these into
// the Win32 version resource; without them the executable ships with none,
// which is one of the things heuristic scanners hold against a file.
[assembly: AssemblyTitle("TidyPika")]
[assembly: AssemblyProduct("TidyPika")]
[assembly: AssemblyDescription("A tiny Windows storage cleaner.")]
[assembly: AssemblyCompany("poko")]
[assembly: AssemblyCopyright("Copyright (c) 2026 poko")]
[assembly: AssemblyVersion("VERSION_PLACEHOLDER")]
[assembly: AssemblyFileVersion("VERSION_PLACEHOLDER")]

/// <summary>
/// Wraps the Flutter build in one executable.
///
/// Flutter keeps its engine DLL and asset folder as separate files on disk, so
/// there is no genuine single-file target. This launcher carries the whole
/// folder as an embedded zip, unpacks it once into a build-stamped directory
/// under LOCALAPPDATA, and starts the app from there — later runs find the
/// directory already populated and skip straight to launching.
///
/// Built against .NET Framework, which ships with every supported version of
/// Windows, so the wrapper adds no runtime requirement of its own.
/// </summary>
internal static class Launcher
{
    /// Replaced at build time with the commit being packaged, so a new build
    /// unpacks beside the old one rather than into a stale directory.
    private const string BuildId = "BUILD_ID_PLACEHOLDER";

    private const string PayloadResource = "payload.zip";
    private const string AppExecutable = "TidyPika.exe";

    private static int Main()
    {
        var home = AppHome();
        var root = Path.Combine(home, BuildId);
        var app = Path.Combine(root, AppExecutable);

        try
        {
            if (!File.Exists(app))
            {
                Unpack(root);
                Prune(home);
            }

            Process.Start(new ProcessStartInfo(app)
            {
                UseShellExecute = false,
                WorkingDirectory = root,
            });

            return 0;
        }
        catch (Exception error)
        {
            Report(error);
            return 1;
        }
    }

    /// <summary>
    /// Where the unpacked build lives.
    ///
    /// Not TEMP. An unsigned executable that writes a program into TEMP and
    /// immediately runs it is the shape of a dropper, and that is how
    /// Defender's machine-learning heuristics score it — Wacatac.B!ml and
    /// friends. Under LOCALAPPDATA it looks like what it is: an application
    /// keeping its files where applications keep them, next to the settings
    /// the app already writes there.
    /// </summary>
    private static string AppHome()
    {
        var local = Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData);

        if (string.IsNullOrEmpty(local))
        {
            local = Path.GetTempPath();
        }

        return Path.Combine(local, "TidyPika");
    }

    /// <summary>
    /// Removes builds left behind by earlier versions.
    ///
    /// TEMP was at least self-cleaning; LOCALAPPDATA is not, and leaving 11 MB
    /// per update behind would be a poor look for a storage cleaner. Only
    /// directories are considered, so the settings files in the same folder
    /// are never touched.
    /// </summary>
    private static void Prune(string home)
    {
        try
        {
            foreach (var directory in Directory.GetDirectories(home))
            {
                if (Path.GetFileName(directory) == BuildId)
                {
                    continue;
                }

                try
                {
                    Directory.Delete(directory, true);
                }
                catch
                {
                    // Most likely that build is still running and holding its
                    // own files open. The next launch will find it again.
                }
            }
        }
        catch
        {
            // Nothing here is worth failing a launch over.
        }
    }

    private static void Unpack(string root)
    {
        // Unpack beside the target and move into place, so a run interrupted
        // half way through does not leave a directory that looks complete.
        var staging = root + "-partial";
        if (Directory.Exists(staging))
        {
            Directory.Delete(staging, true);
        }

        Directory.CreateDirectory(staging);

        var assembly = Assembly.GetExecutingAssembly();
        using (var stream = assembly.GetManifestResourceStream(PayloadResource))
        {
            if (stream == null)
            {
                throw new InvalidOperationException("the payload is missing from this build");
            }

            using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                foreach (var entry in archive.Entries)
                {
                    var path = Path.Combine(staging, entry.FullName);

                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(path);
                        continue;
                    }

                    Directory.CreateDirectory(Path.GetDirectoryName(path));

                    using (var input = entry.Open())
                    using (var output = File.Create(path))
                    {
                        input.CopyTo(output);
                    }
                }
            }
        }

        if (Directory.Exists(root))
        {
            Directory.Delete(root, true);
        }

        Directory.Move(staging, root);
    }

    private static void Report(Exception error)
    {
        // A winexe has no console, so leave the detail somewhere findable.
        try
        {
            var home = AppHome();
            Directory.CreateDirectory(home);

            File.WriteAllText(
                Path.Combine(home, "launcher.log"),
                DateTime.Now + Environment.NewLine + error);
        }
        catch
        {
            // Nothing further to try.
        }
    }
}
