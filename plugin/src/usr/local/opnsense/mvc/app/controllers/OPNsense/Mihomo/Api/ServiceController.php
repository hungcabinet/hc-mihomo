<?php

namespace OPNsense\Mihomo\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\Mihomo\Mihomo';
    protected static $internalServiceTemplate = 'OPNsense/Mihomo';
    protected static $internalServiceEnabled = 'general.enabled';
    protected static $internalServiceName = 'mihomo';

    public function startAction()
    {
        if (!$this->request->isPost()) {
            return ['response' => []];
        }

        $this->persistEnabled('1');
        $backend = new Backend();
        $this->reloadTemplate($backend);
        $response = trim($backend->configdRun(escapeshellarg(static::$internalServiceName) . ' start'));

        return ['response' => $response];
    }

    public function stopAction()
    {
        if (!$this->request->isPost()) {
            return ['response' => []];
        }

        $this->persistEnabled('0');
        $backend = new Backend();
        $this->reloadTemplate($backend);
        $response = trim($backend->configdRun(escapeshellarg(static::$internalServiceName) . ' stop'));

        return ['response' => $response];
    }

    public function restartAction()
    {
        if (!$this->request->isPost()) {
            return ['response' => []];
        }

        $this->persistEnabled('1');
        $backend = new Backend();
        $this->reloadTemplate($backend);
        $response = trim($backend->configdRun(escapeshellarg(static::$internalServiceName) . ' restart'));

        return ['response' => $response];
    }

    public function infoAction()
    {
        $backend = new Backend();
        $status = $this->statusAction();
        $detail = trim($backend->configdRun(escapeshellarg(static::$internalServiceName) . ' status'));
        $version = trim($backend->configdRun('mihomo version'));

        return [
            'status' => $status['status'],
            'detail' => $detail,
            'version' => $version,
            'enabled' => $this->serviceEnabled(),
        ];
    }

    private function persistEnabled($value)
    {
        $model = $this->getModel();
        $model->general->enabled = (string)$value;
        $model->serializeToConfig();
        Config::getInstance()->save();
    }

    private function reloadTemplate(Backend $backend)
    {
        $backend->configdpRun('template reload', [static::$internalServiceTemplate]);
    }
}
