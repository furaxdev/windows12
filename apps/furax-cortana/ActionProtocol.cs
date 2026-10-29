using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace FuraxCortana;

/// <summary>Type d'action que le modèle peut demander. Liste FERMÉE et volontairement
/// restreinte — le modèle ne peut PAS inventer un type d'action arbitraire, seulement
/// utiliser ceux qu'on reconnaît ici.</summary>
internal enum ActionKind
{
    RunCommand,
    OpenApp,
    TypeText,
    ClickAt,
    MoveMouse,
}

internal sealed record ProposedAction(ActionKind Kind, string Payload)
{
    /// <summary>Texte affiché à l'utilisateur dans la carte de confirmation — doit décrire
    /// EXACTEMENT ce qui va s'exécuter, en clair, jamais un résumé édulcoré.</summary>
    public string DescribeForConfirmation() => Kind switch
    {
        ActionKind.RunCommand => $"Exécuter la commande : {Payload}",
        ActionKind.OpenApp => $"Lancer le programme : {Payload}",
        ActionKind.TypeText => $"Taper ce texte dans la fenêtre active : \"{Payload}\"",
        ActionKind.ClickAt => $"Cliquer à l'écran en ({Payload})",
        ActionKind.MoveMouse => $"Déplacer la souris en ({Payload})",
        _ => Payload,
    };
}

/// <summary>Analyse la réponse du modèle à la recherche de balises [ACTION:TYPE]payload
/// [/ACTION]. Protocole volontairement simple en texte brut (pas de JSON) : un petit modèle
/// local quantifié produit du JSON structuré de façon peu fiable, alors que ce format
/// texte avec des balises explicites est plus robuste à analyser même si la sortie du
/// modèle est imparfaite. Toute balise mal formée est ignorée (pas d'exécution de code
/// partiel/ambigu), jamais levée en exception qui planterait le chat.</summary>
internal static class ActionProtocol
{
    private static readonly Regex Tag = new(
        @"\[ACTION:(?<kind>RUN|OPEN_APP|TYPE|CLICK|MOVE)\](?<payload>.*?)\[/ACTION\]",
        RegexOptions.Singleline | RegexOptions.IgnoreCase);

    internal const string SystemPromptSuffix = """

        Si tu dois agir sur l'ordinateur (lancer une commande, ouvrir une application,
        taper du texte dans la fenêtre active, cliquer ou déplacer la souris à l'écran),
        utilise EXACTEMENT ce format, une balise par action :
        [ACTION:RUN]commande ici[/ACTION]
        [ACTION:OPEN_APP]nom.exe[/ACTION]
        [ACTION:TYPE]texte ici[/ACTION]
        [ACTION:CLICK]x,y[/ACTION]
        [ACTION:MOVE]x,y[/ACTION]
        N'exécute JAMAIS rien toi-même : l'utilisateur voit toujours la balise sous forme
        d'une carte à confirmer avant toute exécution réelle. Explique en texte normal ce
        que tu proposes de faire ET pourquoi, en plus de la balise.
        """;

    /// <summary>Retourne le texte affichable (balises retirées, pour ne pas montrer le
    /// format brut au chat) et la liste des actions proposées, dans l'ordre.</summary>
    internal static (string DisplayText, List<ProposedAction> Actions) Parse(string modelOutput)
    {
        var actions = new List<ProposedAction>();
        foreach (Match m in Tag.Matches(modelOutput))
        {
            var kindText = m.Groups["kind"].Value.ToUpperInvariant();
            var payload = m.Groups["payload"].Value.Trim();
            if (string.IsNullOrEmpty(payload))
            {
                continue;
            }
            ActionKind? kind = kindText switch
            {
                "RUN" => ActionKind.RunCommand,
                "OPEN_APP" => ActionKind.OpenApp,
                "TYPE" => ActionKind.TypeText,
                "CLICK" => ActionKind.ClickAt,
                "MOVE" => ActionKind.MoveMouse,
                _ => null,
            };
            if (kind is not null)
            {
                actions.Add(new ProposedAction(kind.Value, payload));
            }
        }

        var displayText = Tag.Replace(modelOutput, "").Trim();
        return (displayText, actions);
    }
}
