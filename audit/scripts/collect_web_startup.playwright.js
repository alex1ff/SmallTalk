async page => {
  const browser = page.context().browser();
  const samples = [];
  let observedEnvironment;
  const launcherUrl = page.url();
  const query = launcherUrl.split('?')[1] ?? '';
  const queryValue = name => query.split('&').map(part => part.split('='))
    .find(([key]) => key === name)?.slice(1).join('=');
  const manifestRunId = queryValue('manifestRunId');
  const playwrightCliVersion = queryValue('playwrightCliVersion');
  const origin = launcherUrl.split('?')[0].replace(/\/$/, '');
  if (!manifestRunId || !playwrightCliVersion || !origin.startsWith('http://127.0.0.1:')) {
    throw new Error('collector must be started by the measured loopback launcher');
  }

  for (let index = 0; index < 10; index += 1) {
    const context = await browser.newContext({
      locale: 'ru-RU',
      serviceWorkers: 'block',
      viewport: {width: 390, height: 844},
    });
    const measuredPage = await context.newPage();
    const devtools = await context.newCDPSession(measuredPage);
    await devtools.send('Network.enable');
    await devtools.send('Network.setCacheDisabled', {cacheDisabled: true});
    await devtools.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: 0,
      downloadThroughput: -1,
      uploadThroughput: -1,
      connectionType: 'wifi',
    });

    const startedAt = Date.now();
    await measuredPage.goto(
      `${origin}/?performance-run=${index}&manifestRunId=${manifestRunId}`,
      {waitUntil: 'domcontentloaded', timeout: 60000},
    );
    const accessibilityButton = measuredPage.getByRole('button', {
      name: 'Enable accessibility',
    });
    await accessibilityButton.waitFor({state: 'attached', timeout: 60000});
    const surfaceReadyMs = Date.now() - startedAt;
    // Flutter exposes this off-screen bootstrap control only to enable its
    // semantics tree. It is measurement setup, not the actionability signal.
    await accessibilityButton.evaluate(element => element.click());
    const firstAction = measuredPage.getByRole('button', {name: /Далее|Next/});
    await firstAction.waitFor({
      state: 'visible',
      timeout: 60000,
    });
    if (!await firstAction.isEnabled()) {
      throw new Error('first onboarding action is disabled');
    }
    await firstAction.click({trial: true});
    const firstInteractiveMs = Date.now() - startedAt;
    if (!observedEnvironment) {
      const browserEnvironment = await measuredPage.evaluate(async () => {
        const frameTimes = [];
        await new Promise(resolve => {
          const tick = time => {
            frameTimes.push(time);
            if (frameTimes.length === 61) resolve();
            else requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
        });
        const durationMs = frameTimes.at(-1) - frameTimes[0];
        const measuredRateHz = 60000 / durationMs;
        return {
          userAgent: navigator.userAgent,
          locale: navigator.language,
          viewport: `${innerWidth}x${innerHeight}@${devicePixelRatio}x`,
          measuredRefreshRateHz: measuredRateHz,
          refreshRateHz: Math.max(30, Math.round(measuredRateHz / 30) * 30),
        };
      });
      observedEnvironment = {
        ...browserEnvironment,
        browserVersion: browser.version(),
        playwrightCliVersion,
        network: '127.0.0.1 local HTTP server; CDP latency 0; throughput unlimited',
        authState: 'signed out; onboarding',
        cacheState: 'cold; fresh context; service workers blocked; HTTP cache disabled',
      };
    }
    const browserMetrics = await measuredPage.evaluate(() => {
      const navigation = performance.getEntriesByType('navigation')[0];
      const resources = performance.getEntriesByType('resource');
      return {
        domContentLoadedMs: navigation.domContentLoadedEventEnd,
        loadEventMs: navigation.loadEventEnd,
        resourceCount: resources.length,
        transferredBytes: resources.reduce(
          (total, resource) => total + resource.transferSize,
          0,
        ),
        usedJsHeapBytes: performance.memory?.usedJSHeapSize ?? null,
      };
    });
    samples.push({surfaceReadyMs, firstInteractiveMs, ...browserMetrics});
    await context.close();
  }

  return {
    schemaVersion: 1,
    manifestRunId,
    scenarioVersion: 'web-onboarding-startup-v1',
    environment: observedEnvironment,
    samples,
  };
}
