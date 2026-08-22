using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

/// <summary>
/// Wraps the Flutter build in one executable.
///
/// Flutter keeps its engine DLL and asset folder as separate files on disk, so
/// there is no genuine single-file target. This launcher carries the whole
/// folder as an embedded zip, unpacks it once into a build-stamped directory
/// under TEMP, and starts the app from there — later runs find the directory
/// already populated and skip straight to launching.
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
        var root = Path.Combine(Path.GetTempPath(), "TidyPika-" + BuildId);
        var app = Path.Combine(root, AppExecutable);

        try
        {
            if (!File.Exists(app))
            {
                Unpack(root);
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
            File.WriteAllText(
                Path.Combine(Path.GetTempPath(), "TidyPika-launcher.log"),
                DateTime.Now + Environment.NewLine + error);
        }
        catch
        {
            // Nothing further to try.
        }
    }
}
