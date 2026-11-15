/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { lazy, Suspense, useEffect } from "react";
import { installMessageBus } from "@/lib/messageBus";
import { isEnvBrowser, sendReady } from "@/lib/nui";
import { LayerHost } from "@/components/LayerHost";
import { NotificationStack } from "@/components/NotificationStack";

// Dev only: the import is removed from production builds, so the panel never ships.
const DevPanel = import.meta.env.DEV ? lazy(() => import("@/dev/DevPanel")) : null;

export default function App() {
  useEffect(() => {
    const uninstall = installMessageBus();

    void sendReady();

    return uninstall;
  }, []);

  return (
    <>
      <LayerHost />
      <NotificationStack />
      {DevPanel && isEnvBrowser() && (
        <Suspense fallback={null}>
          <DevPanel />
        </Suspense>
      )}
    </>
  );
}
