using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using LLama;
using LLama.Common;

namespace FuraxCortana;

/// <summary>Enveloppe LLamaSharp (llama.cpp, MIT) pour l'inférence 100% locale — AUCUN appel
/// réseau n'est fait par ce fichier ni par la bibliothèque sous-jacente une fois le modèle
/// chargé depuis le disque. Vérifié réellement (29/10/2026) : chargement d'un modèle GGUF
/// réel + génération de texte réelle via exactement cette API (LLamaWeights.LoadFromFile ->
/// CreateContext -> InteractiveExecutor.InferAsync), testé sur Linux (llama.cpp est
/// multiplateforme) faute de pouvoir booter du Windows dans cet environnement de dev — la
/// logique est donc prouvée, le chargement natif spécifique à Windows (DLL auto-extraites
/// par le publish self-contained) reste UNCONFIRMED tant que pas testé sur une vraie
/// machine Windows.
///
/// ⚠️ Le modèle n'est JAMAIS fourni par ce projet : aucun fichier .gguf n'est déposé dans
/// l'ISO (ça gonflerait le WIM de plusieurs centaines de Mo à plusieurs Go selon le modèle,
/// et redistribuer les poids d'un tiers dans l'ISO soulève sa propre question de licence/
/// taille, distincte du code ici qui est 100% notre travail + une dépendance MIT). Voir
/// docs/FEATURES.md pour l'emplacement attendu et comment l'utilisateur fournit son propre
/// modèle (licence libre recommandée, ex. Qwen2.5-Instruct-GGUF Apache-2.0, ou Phi-3-mini
/// MIT).</summary>
internal sealed class LocalModel : IDisposable
{
    private readonly LLamaWeights _weights;
    private readonly LLamaContext _context;
    private readonly InteractiveExecutor _executor;

    private LocalModel(LLamaWeights weights, LLamaContext context, InteractiveExecutor executor)
    {
        _weights = weights;
        _context = context;
        _executor = executor;
    }

    /// <summary>Cherche un .gguf dans %LOCALAPPDATA%\FuraxCortana\models — jamais de
    /// téléchargement, jamais de chemin réseau. Retourne null si rien n'est trouvé (l'appelant
    /// doit alors afficher un message clair à l'utilisateur, pas planter).</summary>
    internal static string? FindModelFile()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FuraxCortana", "models");
        if (!Directory.Exists(dir))
        {
            return null;
        }
        var files = Directory.GetFiles(dir, "*.gguf");
        return files.Length > 0 ? files[0] : null;
    }

    internal static LocalModel? TryLoad(string modelPath, out string? error)
    {
        try
        {
            var modelParams = new ModelParams(modelPath) { ContextSize = 2048, GpuLayerCount = 0 };
            var weights = LLamaWeights.LoadFromFile(modelParams);
            var context = weights.CreateContext(modelParams, logger: null);
            var executor = new InteractiveExecutor(context);
            error = null;
            return new LocalModel(weights, context, executor);
        }
        catch (Exception ex)
        {
            // Jamais remonté comme exception non gérée à l'UI : un échec de chargement de
            // modèle (fichier corrompu, format non supporté, pas assez de RAM) doit juste
            // désactiver le chat avec un message clair, pas planter l'appli.
            error = ex.Message;
            return null;
        }
    }

    internal async IAsyncEnumerable<string> GenerateAsync(string prompt)
    {
        var inferenceParams = new InferenceParams { MaxTokens = 400 };
        await foreach (var token in _executor.InferAsync(prompt, inferenceParams))
        {
            yield return token;
        }
    }

    public void Dispose()
    {
        _context.Dispose();
        _weights.Dispose();
    }
}
