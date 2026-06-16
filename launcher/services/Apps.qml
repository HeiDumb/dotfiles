pragma Singleton

import qs.config
import qs.services
import qs.utils
import Caelestia
import Quickshell

Searcher {
    id: root

    function isSteamEntry(entry: DesktopEntry): bool {
        const id = (entry?.id ?? "").toLowerCase();
        const name = (entry?.name ?? "").toLowerCase();
        const execString = (entry?.execString ?? "").toLowerCase();
        const command = (entry?.command ?? []).join(" ").toLowerCase();

        return id === "steam.desktop"
            || id === "steam"
            || name === "steam"
            || execString.includes("/steam")
            || command.includes("/steam")
            || command.split(" ").includes("steam");
    }

    function registerLaunchSource(item: var): void {
        const visual = item?.launchSourceItem ?? item;
        if (!visual || !visual.mapToItem)
            return;

        try {
            const width = Math.max(24, visual.width || visual.implicitWidth || 72);
            const height = Math.max(24, visual.height || visual.implicitHeight || width);
            const center = visual.mapToItem(null, width / 2, height / 2);
            const visualScale = Math.max(0.1, Math.abs(visual.scale ?? 1));
            const sourceWidth = Math.max(24, width * visualScale);
            const sourceHeight = Math.max(24, height * visualScale);
            const x = Math.round(center.x - sourceWidth / 2);
            const y = Math.round(center.y - sourceHeight / 2);

            Hypr.dispatch(`voiddecksource ${x} ${y} ${Math.round(sourceWidth)} ${Math.round(sourceHeight)}`);
        } catch (error) {
            console.warn(`[Apps] Unable to register VoidDeck launch source: ${error}`);
        }
    }

    function launch(entry: DesktopEntry, sourceItem: var): void {
        if (sourceItem)
            registerLaunchSource(sourceItem);

        appDb.incrementFrequency(entry.id);

        if (root.isSteamEntry(entry)) {
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: entry.workingDirectory
            });
        } else if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...Config.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: ["app2unit", "--", ...entry.command],
                workingDirectory: entry.workingDirectory
            });
    }

    function search(search: string): list<var> {
        const prefix = Config.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];

            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry);
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: Config.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: Config.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(Config.launcher.hiddenApps, a.id))
    }
}
