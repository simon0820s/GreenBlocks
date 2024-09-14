// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/GreenProjects.sol";  // Asegúrate de que la ruta sea correcta

contract DeployGreenProjects is Script {
    function run() external {
        vm.startBroadcast();  // Iniciar la transmisión de la transacción
        new GreenProjects();  // Desplegar el contrato
        vm.stopBroadcast();   // Detener la transmisión
    }
}