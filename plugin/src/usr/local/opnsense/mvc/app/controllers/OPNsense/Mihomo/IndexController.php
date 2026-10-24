<?php

namespace OPNsense\Mihomo;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/Mihomo/index');
    }
}
