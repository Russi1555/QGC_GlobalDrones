/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.FactControls
// 3D Viewer modules
import Viewer3D
import Qt5Compat.GraphicalEffects

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedActionList:      guidedActionList
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl


    property real  mainViewHeight: parent.height*5/6
    property real  mainViewWidth : parent.width - (parent.height - mainViewHeight) //garantir simetria
    property bool _cameraExchangeActive : false
    property var _pct_bateria: 0//_activeVehicle.batteries.get(0).percentRemaining.valueString + "%"
    property var _tensao_bateria: _activeVehicle? 9 : 0 //modificado em MainWindow
    property var _current_bateria: _activeVehicle? 9 : 0
    property var _current_generator: 0
    property real _gasolina: 0//_activeVehicle.batteries.get(1).voltage

    property int _satCount: 0
    property int _satPDOP: 0
    property int _rcQuality: 0
    property var _current_battery_ARRAY: []
    property var _current_generator_ARRAY: []
    property var _returnFunctionArray: []
    property bool flagAlertaGerador: false
    property real oldGeneratorMediamValue: 0
    property int  maxGeneratorCurrent: 120
    property var  _distanceToHome:     _activeVehicle.distanceToHome.rawValue.toFixed(2)
    property var  _distanceToWP: _activeVehicle.distanceToNextWP.rawValue.toFixed(2)
    property var _mavlinkLossPercent: _activeVehicle.mavlinkLossPercent.rawValue


    property real _tensao_cell_1: 50 //PLACEHOLDER
    property real _tensao_cell_2: 45 //PLACEHOLDER
    property real _tensao_cell_3: 70 //PLACEHOLDER
    property real _tensao_cell_4: 20 //PLACEHOLDER
    property real _tensao_cell_5: 80 //PLACEHOLDER
    property real _tensao_cell_6: 50 //PLACEHOLDER
    property real _tensao_cell_7: 60 //PLACEHOLDER
    property real _tensao_cell_8: 28 //PLACEHOLDER
    property real _tensao_cell_9: 80 //PLACEHOLDER
    property real _tensao_cell_10: 50 //PLACEHOLDER
    property real _tensao_cell_11: 40 //PLACEHOLDER
    property real _tensao_cell_12: 90 //PLACEHOLDER

    property real _aceleracao_rotor_1: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_1_ARRAY: []
    property real _aceleracao_rotor_2: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_2_ARRAY: []
    property real _aceleracao_rotor_3: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_3_ARRAY: []
    property real _aceleracao_rotor_4: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_4_ARRAY: []
    property real _aceleracao_rotor_5: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_5_ARRAY: []
    property real _aceleracao_rotor_6: 1100 //PLACEHOLDER
    property var  aceleracao_rotor_6_ARRAY: []

    property real medAceleracaoRotor1: 1500
    property real medAceleracaoRotor2: 1500
    property real medAceleracaoRotor3: 1500
    property real medAceleracaoRotor4: 1500
    property real medAceleracaoRotor5: 1500
    property real medAceleracaoRotor6: 1500

    property bool _selected_rotor_1: false
    property bool _selected_rotor_2: false
    property bool _selected_rotor_3: false
    property bool _selected_rotor_4: false
    property bool _selected_rotor_5: false
    property bool _selected_rotor_6: false

    property real _maxVel: _activeVehicle.parameterManager.componentIds()


    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets



    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMessageIndicatorTool() {
        toolbar.dropMessageIndicatorTool();
    }

    function generatorAlert(batValues, gerValues, oldGerMed){ //TODO: incluir condicional tensão da bateria < 44V
        var medBat = 0;
        var medGer = 0;
        var flagAlert = false;
        for (var i = 0; i<20; i++){
            medBat = medBat + batValues[i];
            medGer = medGer + gerValues[i];
        }
        medBat = medBat;
        medGer = medGer;

        //Se a média da corrente do gerador esta próxima de 0, levanta flag
        if (Math.abs(medGer)<20){
            flagAlert = true;
        }
        //Se a media da corrente da bateria é maior que do gerador E a média do gerador está caindo, levanta flag
        else if (medBat > medGer && oldGerMed > medGer) {
            flagAlert = true;
            //console.log(medBat,medGer, oldGerMed)
        }

        return [flagAlert, medGer];
    }

    function accelerationPercentageToRadius(percentage){
        return percentage*0.015

    }

    Timer{
        id: propertyValuesUpdater
        interval: 1000
        running: true
        repeat: true
        onTriggered:{
            _pct_bateria = (((_tensao_bateria/100)/50)*100).toFixed(2)//_activeVehicle.batteries.get(0).percentRemaining.rawValue
            _satCount = _activeVehicle.gps.count.rawValue
            _satPDOP = _activeVehicle.gps.lock.rawValue
            _rcQuality = _activeVehicle.rcRSSI


            //Monitoramento do gerador TODO: DESCOMENTAR DEPOIS
            //_current_battery_ARRAY.push(_current_bateria) //populando dinamicamente array de valores de corrente da bateria
            //_current_generator_ARRAY.push(_current_generator)//populando dinamicamente array de valores de corrente do gerador

            //TODO: DELETAR DEPOIS. APENAS TESTE
            //_current_generator = Math.floor(Math.random() * 120)
            _current_battery_ARRAY.push(Math.floor(Math.random() * 120))
            _current_generator_ARRAY.push(_current_generator)
            _aceleracao_rotor_1 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_1_ARRAY.push(_aceleracao_rotor_1)
            _aceleracao_rotor_2 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_2_ARRAY.push(_aceleracao_rotor_2)
            _aceleracao_rotor_3 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_3_ARRAY.push(_aceleracao_rotor_3)
            _aceleracao_rotor_4 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_4_ARRAY.push(_aceleracao_rotor_4)
            _aceleracao_rotor_5 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_5_ARRAY.push(_aceleracao_rotor_5)
            _aceleracao_rotor_6 = Math.floor(Math.random()*1000) + 1000
            aceleracao_rotor_6_ARRAY.push(_aceleracao_rotor_6)

            //AQUI PRA CIMA É SÓ PRA TESTE
           // console.log((oldGeneratorMediamValue/20)/maxGeneratorCurrent, (40/maxGeneratorCurrent))
            //_mavlinkLossPercent = _activeVehicle.mavlinkLossPercent.rawValue

           // console.log("maxvel: ",_maxVel)
            //var params = _activeVehicle.parameterNames(1); // Chama a função C++
            //console.log("Parameters:", params); // Imprime no console do QML
            //params.forEach(param => console.log(param.toString())); //TODO: typeError. QStringList e QString não são reconhecidos pelo QML padrão. Resolver isso depois


            if(_current_generator_ARRAY.length === 20){ //sabendo que recebemos um dado novo a cada 0.1 segundos, (ver c/ Erich)
                _returnFunctionArray = generatorAlert(_current_battery_ARRAY, _current_generator_ARRAY, oldGeneratorMediamValue);//executa função
                flagAlertaGerador = _returnFunctionArray[0]; //atualiza flag geral com valor booleano retornado da função
                oldGeneratorMediamValue = _returnFunctionArray[1]; //atualiza valor de média
                _current_battery_ARRAY.shift(); //apaga primeiro elemento (ver c/Erich se é pra apagar o primeiro elemento ou todos)
                _current_generator_ARRAY.shift();
                //console.log(_current_battery_ARRAY);
                //console.log(_current_generator_ARRAY);
            }
            if(aceleracao_rotor_1_ARRAY.length ===20){
                var temp1 = 0;
                var temp2 = 0;
                var temp3 = 0;
                var temp4 = 0;
                var temp5 = 0;
                var temp6 = 0;
                for (var i = 0; i<20; i++){
                    temp1 = temp1 + aceleracao_rotor_1_ARRAY[i];
                    temp2 = temp2 + aceleracao_rotor_2_ARRAY[i];
                    temp3 = temp3 + aceleracao_rotor_3_ARRAY[i];
                    temp4 = temp4 + aceleracao_rotor_4_ARRAY[i];
                    temp5 = temp5 + aceleracao_rotor_5_ARRAY[i];
                    temp6 = temp6 + aceleracao_rotor_6_ARRAY[i];
                }
                medAceleracaoRotor1 = temp1/20
                medAceleracaoRotor2 = temp2/20
                medAceleracaoRotor3 = temp3/20
                medAceleracaoRotor4 = temp4/20
                medAceleracaoRotor5 = temp5/20
                medAceleracaoRotor6 = temp6/20
             //   console.log("medAccell1", medAceleracaoRotor1)

                aceleracao_rotor_1_ARRAY.shift();
                aceleracao_rotor_2_ARRAY.shift();
                aceleracao_rotor_3_ARRAY.shift();
                aceleracao_rotor_4_ARRAY.shift();
                aceleracao_rotor_5_ARRAY.shift();
                aceleracao_rotor_6_ARRAY.shift();
            }
            //console.log(_pct_bateria)
            //console.log(_pct_bateria/100)
        }
    }

    //**************************************************************************************************//
    //                          BOTTOM VIEW AREA                                                        //
    //**************************************************************************************************//
    Item {
        id: bottomDataArea
        anchors.bottom : parent.bottom
        anchors.left : parent.bottom
        width : parent.width
        height: parent.height - mainViewHeight



        Rectangle {
                id: gradientBar
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop { position: 0.7; color:  qgcPal.toolbarBackground} // Top color
                    GradientStop { position: 1.0; color:  toolbar._mainStatusBGColor} // Bottom color
                }
            }

        QGCColoredImage {
                id: batteryPercentageIcon
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.margins:    _toolsMargin
                width:              height
                height:             parent.height*2/3
                source:             "/qmlimages/Battery.svg"
                fillMode:           Image.PreserveAspectFit
                color:              "white"
                visible: true
            }

        Rectangle{
                id: batteryPercentageBar
                anchors.top: batteryPercentageIcon.top
                anchors.left: batteryPercentageIcon.left
                //anchors.margins: _toolsMargin
                width: batteryPercentageIcon.width
                height: batteryPercentageIcon.height
                color: "transparent"//batMouseArea.containsMouse? "green": "red" //Isso aqui vai mudar dependendo do valor de _gasolina
                visible: false
                Rectangle{
                    y: parent.height*0.1
                    anchors.horizontalCenter: parent.horizontalCenter
                    //anchors.left: parent.left
                    width: parent.width/2
                    height: parent.height*0.85 //fixo pra não ultrapassar o desenho
                    color: (_pct_bateria) > 50 ? "green" : ((_pct_bateria) > 30 ? "orange" : "red") //cor dinamica de acordo com o _pct_bateria
                }
                Rectangle{ //BARRA DE ALTURA DINAMICA PRA INDICAR O NÍVEL DE bateria -> HEIGHT = 1-bateria%

                     anchors.horizontalCenter: parent.horizontalCenter
                     //anchors.left: parent.left
                     width: parent.width/2
                     height: parent.height*(0.15 + 0.85*(1-_pct_bateria/100) )// bateria | dinamico de acordo com 1-(% bateria). cor há de ser dinamica também
                     color: qgcPal.toolbarBackground
                }

       }

        OpacityMask{
            anchors.fill: batteryPercentageBar
            source: batteryPercentageBar
            maskSource: batteryPercentageIcon
            invert: true
            MouseArea{
                id: batMouseArea
                anchors.fill: parent
                hoverEnabled : true

            }
        }
        Rectangle{
            id: textBoxBatteryInfo
            anchors.verticalCenter: batteryPercentageIcon .verticalCenter
            anchors.horizontalCenter: batteryPercentageIcon.horizontalCenter
            height: batteryPercentageIcon.height/2
            width: batteryPercentageIcon.width
            visible: batMouseArea.containsMouse? true: false
            color: "black"
            border.width: 1
            border.color: "lightgray"

        }
        ColumnLayout {
                id:                     batteryInfoColumn
                anchors.verticalCenter: batteryPercentageIcon.verticalCenter
                anchors.horizontalCenter: batteryPercentageIcon.horizontalCenter
                spacing:                0
                visible: textBoxBatteryInfo.visible

                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   _pct_bateria > 9? _pct_bateria+"%": "0"+_pct_bateria+"%"
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                    visible: textBoxBatteryInfo.visible
                    font.bold: true
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   (_tensao_bateria/100) + " V"
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                    visible: textBoxBatteryInfo.visible
                    font.bold: true
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   (_current_bateria/100) + " mA"
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                    visible: textBoxBatteryInfo.visible
                    font.bold: true
                }

            }

        Rectangle {
               id: cellsTensionArea
               anchors.top: parent.top
               anchors.left: batteryPercentageIcon.right
               anchors.margins: _toolsMargin * 1.5
               width: height * 2
               height: batteryPercentageIcon.height
               color: "black" // Background color

               // Borda com aparência de aço
               Rectangle {
                   anchors.fill: parent
                   color: "transparent"
                   border.width: 2
                   z: parent.z+13
                   border.color: "lightgray" // Cor base da borda
               }
               Rectangle {
                       anchors.fill: parent
                       z: -1
                       color: "black"
                       opacity: 0.3
                       scale: 1.05
                       anchors.verticalCenter: parent.verticalCenter
                       anchors.horizontalCenter: parent.horizontalCenter
                   }

               // Modelo dinâmico com tensões das células
                   ListModel {
                       id: tensaoCelasModel
                   }

                   // Popula o modelo com valores dinamicamente
                   Component.onCompleted: {
                       tensaoCelasModel.append({ tensao: _tensao_cell_1 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_2 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_3 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_4 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_5 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_6 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_7 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_8 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_9 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_10 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_11 });
                       tensaoCelasModel.append({ tensao: _tensao_cell_12 });
                   }

                   Timer{//Atualiza os valores periodicamente [TODO: mudar interval depois]
                        interval: 10000; running: true; repeat: true
                        onTriggered: {
                        tensaoCelasModel.set(0, { tensao: _tensao_cell_1 });
                        tensaoCelasModel.set(1, { tensao: _tensao_cell_2 });
                        tensaoCelasModel.set(2, { tensao: _tensao_cell_3 });
                        tensaoCelasModel.set(3, { tensao: _tensao_cell_4 });
                        tensaoCelasModel.set(4, { tensao: _tensao_cell_5 });
                        tensaoCelasModel.set(5, { tensao: _tensao_cell_6 });
                        tensaoCelasModel.set(6, { tensao: _tensao_cell_7 });
                        tensaoCelasModel.set(7, { tensao: _tensao_cell_8 });
                        tensaoCelasModel.set(8, { tensao: _tensao_cell_9 });
                        tensaoCelasModel.set(9, { tensao: _tensao_cell_10 });
                        tensaoCelasModel.set(10, { tensao: _tensao_cell_11 });
                        tensaoCelasModel.set(11, { tensao: 10 });
                       }
                    }

                   Repeater {
                       model: tensaoCelasModel

                       Rectangle {
                           width: parent.width / 12
                           height: model.tensao // Altura proporcional à tensão
                           x: index * parent.width / 12 // Posiciona horizontalmente
                           anchors.bottom: parent.bottom
                           z: parent.z + 1
                           color: "green"
                           border.color: "black"//index === 0 ? (motor1_selected ? "yellow" : "black") : "black"
                           border.width: 3//index === 0 && motor1_selected ? 3 : 1

                           MouseArea { // Torna a barra interativa
                               anchors.fill: parent
                               onClicked: {console.log("Célula", index + 1, "tensão:", model.tensao);
                               console.log(_activeVehicle)
                                   console.log(_activeVehicle.batteries.count)
                                   console.log(_activeVehicle.batteries.get(0).percentRemaining.valueString)
                                   console.log(_distanceToHome)
                                   console.log(_distanceToWP)
                               }

                           }
                       }
                    }

           }

        //gasolina
        QGCColoredImage {
               id: gasolinePercentageIcon
               anchors.top:        parent.top
               anchors.left:       cellsTensionArea.right
               anchors.margins:    _toolsMargin
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/GasCan.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
               visible: false
           }
        DropShadow {
                anchors.fill: gasolinePercentageIcon
                source: gasolinePercentageIcon
                color: "#80000000" // Semi-transparent black shadow
                radius: 8
                samples:17
                spread: 0
                verticalOffset: 5
                horizontalOffset: 5
            }
        Rectangle{
            id: gasolineIconColorLevelBackground
            anchors.fill: gasolinePercentageIcon
            color: "green"
            visible: false
        }
        Rectangle{
                id: gasolinePercentageBar
                anchors.top: gasolinePercentageIcon.top
                anchors.left: gasolinePercentageIcon.left
                //anchors.margins: _toolsMargin
                width: gasolinePercentageIcon.width
                height: gasolinePercentageIcon.height
                color: _gasolina > 0.50 ? "green" : (_gasolina > 0.2 ? "orange" : "red") //gasMouseArea.containsMouse? "green": "red" //Isso aqui vai mudar dependendo do valor de _gasolina
                visible: false
                Rectangle{ //BARRA DE ALTURA DINAMICA PRA INDICAR O NÍVEL DE GASOLINA -> HEIGHT = 1-GASOLINA%
                     anchors.top: parent.top
                     anchors.left: parent.left
                     width: parent.width
                     height: parent.height*(1-_gasolina) // _gasolina | dinamico de acordo com 1-(% gasolina). cor há de ser dinamica também
                     color: "black" // possível trocar pra outra cor se o contraste estiver ruim. talvez branco
                }

           }
        OpacityMask{
            anchors.fill: gasolinePercentageBar
            source: gasolinePercentageBar
            maskSource: gasolinePercentageIcon
            MouseArea{
                id: gasMouseArea
                anchors.fill: parent
                hoverEnabled : true

            }
        }

        Rectangle{
            id: textBoxGasolinePercentage
            anchors.verticalCenter: gasolinePercentageIcon.verticalCenter
            anchors.horizontalCenter: gasolinePercentageIcon.horizontalCenter
            height: gasolinePercentageIcon.height/4
            width: gasolinePercentageIcon.width/2
            visible: gasMouseArea.containsMouse? true: false
            color: "black"
            border.width: 1
            border.color: "lightgray"

        }
        Text{
            anchors.fill: textBoxGasolinePercentage
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: _gasolina *100 + "%"
            font.bold: true
            color: "white"
            visible: textBoxGasolinePercentage.visible
        }




        //operação do gerador (pode ser pop-up por que é fudido de importante?) incluir pop-up/cor dinamica/etc
        QGCColoredImage {
               id: generatorFunctionalityIcon
               anchors.top:        parent.top
               anchors.left:       gasolinePercentageBar.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/Generator.svg"
               fillMode:           Image.PreserveAspectFit
               color:              !flagAlertaGerador ? "white" : "orange" //vai receber o retorno da função. Ou vai estar verde ou vai estar vermelho/laranja. Sem rolo

        }
        DropShadow {
                anchors.fill: generatorFunctionalityIcon
                source: generatorFunctionalityIcon
                color: "#80000000" // Semi-transparent black shadow
                radius: 8
                samples:17
                spread: 0
                verticalOffset: 5
                horizontalOffset: 5
            }

        OpacityMask{
            anchors.fill: generatorFunctionalityIcon
            source: generatorFunctionalityIcon
            maskSource: generatorFunctionalityIcon
            MouseArea{
                id: generatorMouseArea
                anchors.fill: parent
                hoverEnabled : true

            }
        }



            Rectangle{
                //anchors.fill:parent
                id: generatorCurrentBar
                anchors.left: generatorFunctionalityIcon.right
                anchors.top: parent.top
                anchors.margins: _toolsMargin*2
                width:height/3
                height: parent.height*2/3
                color:"green"
                //z:1000000
                Rectangle{
                    anchors.top:generatorCurrentBar.top
                    anchors.left:generatorCurrentBar.left
                    width:generatorCurrentBar.width
                    height: generatorCurrentBar.height * (1-(_current_generator/maxGeneratorCurrent))
                    color:"black"
                }
                Rectangle{
                    anchors.fill:parent
                    border.width:2
                    border.color: "lightgray"
                    color:"transparent"
                }
                Rectangle{
                    anchors.horizontalCenter: generatorCurrentBar.horizontalCenter
                    width: generatorCurrentBar.width + _toolsMargin
                    height: generatorCurrentBar.height/20
                    y: generatorCurrentBar.height*(oldGeneratorMediamValue/20)/maxGeneratorCurrent
                    color: "white"
                    border.width:1
                    border.color:"black"
                }
            }

            Rectangle{
                id: textBoxGeneratorInfo
                anchors.verticalCenter: generatorFunctionalityIcon.verticalCenter
                anchors.horizontalCenter: generatorFunctionalityIcon.horizontalCenter
                height: generatorFunctionalityIcon.height/2
                width: generatorFunctionalityIcon.width
                visible: generatorMouseArea.containsMouse? true: false
                color: "black"
                border.width: 1
                border.color: "lightgray"
            }
            ColumnLayout {
                    id:                     generatorInfoColumn
                    anchors.fill: textBoxGeneratorInfo
                    spacing:                0
                    visible: textBoxGeneratorInfo.visible


                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   _current_generator + "A"
                        font.bold: true
                        //font.pointSize:         ScreenTools.mediumFontPixelHeight
                    }

                }



        //satelite https://forest-gis.com/2018/01/acuracia-gps-o-que-sao-pdop-hdop-gdop-multi-caminho-e-outros.html/?srsltid=AfmBOorX7DD9JggA1vLTP2DuhOK44T28jHasCbLA0nv5nSnLX7irYLlW
        //activeVehicle.gps.count.rawValue (NUM SATELITES); _activeVehicle.gps.hdop.rawValue (HDOP); globals.activeVehicle.gps.lock.rawValue (PDOP)
        QGCColoredImage {
               id: satteliteInformationIcon
               anchors.top:        parent.top
               anchors.left:       generatorCurrentBar.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/Gps.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }
        DropShadow {
                anchors.fill: satteliteInformationIcon
                source: satteliteInformationIcon
                color: "#80000000" // Semi-transparent black shadow
                radius: 8
                samples:17
                spread: 0
                verticalOffset: 5
                horizontalOffset: 5
            }
        OpacityMask{
            anchors.fill: satteliteInformationIcon
            source: satteliteInformationIcon
            maskSource: satteliteInformationIcon
            MouseArea{
                id: satMouseArea
                anchors.fill: parent
                hoverEnabled : true

            }
        }
        Rectangle{
            id: textBoxSatteliteInfo
            anchors.verticalCenter: satteliteInformationIcon.verticalCenter
            anchors.horizontalCenter: satteliteInformationIcon.horizontalCenter
            height: satteliteInformationIcon.height/2
            width: satteliteInformationIcon.width
            visible: satMouseArea.containsMouse? true: false
            color: "black"
            border.width: 1
            border.color: "lightgray"
        }
        ColumnLayout {
                id:                     satteliteInfoColumn
                anchors.fill: textBoxSatteliteInfo
                spacing:                0
                visible: textBoxSatteliteInfo.visible


                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "Count: " + _satCount
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "PDOP: "+ _satPDOP
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }

            }

        //enlace
        QGCColoredImage {
               id: rcInformationIcon
               anchors.top:        parent.top
               anchors.left:       satteliteInformationIcon.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/RC.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
               visible: false
            }

        Rectangle{
                id: rcQualityBar
                anchors.top: parent.top
                anchors.left: rcInformationIcon.left
                anchors.margins: _toolsMargin
                width: rcInformationIcon.width
                height: parent.height*2/3
                color: rcMouseArea.containsMouse? "green": "red"
                visible: false

                Rectangle{
                     anchors.top: parent.top
                     anchors.left: parent.left
                     width: parent.width
                     height: parent.height*((0/255)) // dinamico de acordo com 1-(% RC). cor há de ser dinamica também. Ver como pegar esse valor
                     color: "black"
                }

           }

        OpacityMask{
            anchors.fill: rcQualityBar
            source: rcQualityBar
            maskSource: rcInformationIcon
            MouseArea{
                id: rcMouseArea
                anchors.fill: parent
                hoverEnabled : true

            }
    }
        Rectangle{
            id: textBoxRCInfo
            anchors.verticalCenter: rcInformationIcon.verticalCenter
            anchors.horizontalCenter: rcInformationIcon.horizontalCenter
            height: satteliteInformationIcon.height/2
            width: satteliteInformationIcon.width
            visible: rcMouseArea.containsMouse? true: false
            color: "black"
            border.width: 1
            border.color: "lightgray"
        }
        ColumnLayout {
                id:                     rcInfoColumn
                anchors.fill: textBoxRCInfo
                spacing:                0
                visible: textBoxRCInfo.visible


                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "RCSSI: " + _rcQuality
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "pkgs lost: " + _mavlinkLossPercent +"%"
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
            }


        //Temperatura Gerador
        QGCColoredImage {
               id: motorTemperatureInformationIcon
               anchors.top:        parent.top
               anchors.left:       rcQualityBar.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/MotorTemp.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }
        QGCColoredImage {
               id: motorTemperatureInformationIcon2
               anchors.top:        parent.top
               anchors.left:       rcQualityBar.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/MotorTermometer.png"
               fillMode:           Image.PreserveAspectFit
               color:              "yellow"
            }

        Rectangle{
            id: textBoxMotorTempInfo
            anchors.verticalCenter: motorTemperatureInformationIcon.verticalCenter
            anchors.horizontalCenter: motorTemperatureInformationIcon.horizontalCenter
            height: motorTemperatureInformationIcon.height/2
            width: motorTemperatureInformationIcon.width
            visible: motorTempMouseArea.containsMouse? true: false
            color: "black"
            border.width: 1
            border.color: "lightgray"


        }
        MouseArea{
        id:motorTempMouseArea
        anchors.fill: motorTemperatureInformationIcon
        hoverEnabled: true
        }
        ColumnLayout {
                id: motorTempInfoColumn
                anchors.fill: textBoxMotorTempInfo
                spacing:                0
                visible: textBoxMotorTempInfo.visible


                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "30° C"
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }

                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "RPM: 6000"
                    font.bold: true
                    //font.pointSize:         ScreenTools.mediumFontPixelHeight
                }

            }



        //Temperatura Rotores
        QGCColoredImage {
               id: rotorAccelerationInformationIcon
               anchors.top:        parent.top
               anchors.left:       motorTemperatureInformationIcon.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/rotorsAccell.png"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }
        Rectangle {
               id: rotorsTempArea
               anchors.top: parent.top
               anchors.left: rotorAccelerationInformationIcon.right
               anchors.margins: _toolsMargin * 1.5
               width: height * 2
               height: rotorAccelerationInformationIcon.height
               color: "black" // Background color

               // Borda com aparência de aço
               Rectangle {
                   anchors.fill: parent
                   color: "transparent"
                   border.width: 2
                   z: parent.z+13
                   border.color: "lightgray" // Cor base da borda
               }
               Rectangle {
                       anchors.fill: parent
                       z: -1
                       color: "black"
                       opacity: 0.3
                       scale: 1.05
                       anchors.verticalCenter: parent.verticalCenter
                       anchors.horizontalCenter: parent.horizontalCenter
                   }

               // Modelo dinâmico com tensões das células
                   ListModel {
                       id: accellRotorModel
                   }

                   // Popula o modelo com valores dinamicamente
                   Component.onCompleted: {
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_1 - 1000)/1000 });
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_2 - 1000)/1000 });
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_3 - 1000)/1000 });
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_4 - 1000)/1000 });
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_5 - 1000)/1000 });
                       accellRotorModel.append({ aceleracao: (_aceleracao_rotor_6 - 1000)/1000 });

                   }

                   Timer{//Atualiza os valores periodicamente [TODO: mudar interval depois]
                        interval: 1000; running: true; repeat: true
                        onTriggered: {
                        accellRotorModel.set(0, { aceleracao: (_aceleracao_rotor_1 - 1000)/1000 });
                        accellRotorModel.set(1, { aceleracao: (_aceleracao_rotor_2 - 1000)/1000 });
                        accellRotorModel.set(2, { aceleracao: (_aceleracao_rotor_3 - 1000)/1000 });
                        accellRotorModel.set(3, { aceleracao: (_aceleracao_rotor_4 - 1000)/1000 });
                        accellRotorModel.set(4, { aceleracao: (_aceleracao_rotor_5 - 1000)/1000 });
                        accellRotorModel.set(5, { aceleracao: (_aceleracao_rotor_6 - 1000)/1000 });
                        //console.log((_aceleracao_rotor_1-1000)/1000,_aceleracao_rotor_2,_aceleracao_rotor_3)
                       }
                    }

                   Repeater {
                       model: accellRotorModel

                       Rectangle {
                           width: parent.width / 6
                           height: model.aceleracao* parent.height // Altura proporcional à aceleracao
                           x: index * parent.width / 6 // Posiciona horizontalmente
                           anchors.bottom: parent.bottom
                           z: parent.z + 1
                           color: "green"
                           border.color: {
                               if(index == 0 && _selected_rotor_1) return "yellow"
                               else if (index == 1 && _selected_rotor_2) return "yellow"
                               else if (index == 2 && _selected_rotor_3) return "yellow"
                               else if (index == 3 && _selected_rotor_4) return "yellow"
                               else if (index == 4 && _selected_rotor_5) return "yellow"
                               else if (index == 5 && _selected_rotor_6) return "yellow"
                               else return "black"
                           }//"black"//index === 0 ? (motor1_selected ? "yellow" : "black") : "black"
                        border.width: 3//index === 0 && motor1_selected ? 3 : 1
                           MouseArea { // Torna a barra interativa
                               anchors.fill: parent
                               hoverEnabled: true
                               onClicked: {
                                    console.log("Célula", index + 1, "tensão:", model.tensao);
                                    console.log(_activeVehicle)
                                    console.log(_activeVehicle.batteries.count)
                                    console.log(_activeVehicle.batteries.get(0).percentRemaining.valueString)

                               }

                               onContainsMouseChanged: {
                                if(index == 0){_selected_rotor_1 = !_selected_rotor_1 }
                                else if(index == 1){_selected_rotor_2 = !_selected_rotor_2 }
                                else if(index == 2){_selected_rotor_3 = !_selected_rotor_3 }
                                else if(index == 3){_selected_rotor_4 = !_selected_rotor_4 }
                                else if(index == 4){_selected_rotor_5 = !_selected_rotor_5 }
                                else if(index == 5){_selected_rotor_6 = !_selected_rotor_6 }
                               }
                           }

                       }



                   }

                   Repeater{
                   model: accellRotorModel
                   Rectangle{
                       width: parent.width/6
                       height: parent.height/20
                       y: {
                           if(index == 0) return parent.height*((medAceleracaoRotor1-1000)/1000)
                           else if (index == 1) return parent.height*((medAceleracaoRotor2-1000)/1000)
                           else if (index == 2) return parent.height*((medAceleracaoRotor3-1000)/1000)
                           else if (index == 3) return parent.height*((medAceleracaoRotor4-1000)/1000)
                           else if (index == 4) return parent.height*((medAceleracaoRotor5-1000)/1000)
                           else if (index == 5) return parent.height*((medAceleracaoRotor6-1000)/1000)
                       }//parent.height*(oldGeneratorMediamValue/20)/maxGeneratorCurrent
                       x: index*parent.width/6
                       z:1000
                       color: "white"
                       border.color:"black"
                       border.width:1
                   }
                   }

           }


    }




//**************************************************************************************************//
//                          LATERAL VIEW AREA                                                       //
//**************************************************************************************************//
    FlyViewToolBar {
        id:         toolbarsize
        visible:   false// !QGroundControl.videoManager.fullScreen
    }
    Item {
        id: lateralDataArea
        anchors.right : parent.right
        anchors.bottom : bottomDataArea.top
        anchors.top:toolbarsize.bottom
        width : parent.width - mainViewWidth
        height: mainViewHeight
        //Ilustração Aeronave {EXPERIMENTAR COLOCAR NO FUNDO DO LATERAL VIEW AREA PRA MANTER CENTRALIZAÇÃO HORIZONTAL}

        Rectangle {
                anchors.fill: parent
                color:qgcPal.toolbarBackground
                //gradient: Gradient {
                //    GradientStop { position: 0.7; color:  qgcPal.toolbarBackground} // Top color
                //    GradientStop { position: 1.0; color:  toolbar._mainStatusBGColor} // Bottom color
                //}
            }
        Item{
            id: flightTimeArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            /*Text {
                    text: "Flight Time\n 00.00.00"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: maxSpeedText.top
                    anchors.margins: _toolsMargin // Adiciona um pequeno espaço do canto
                    font.bold: true
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    font.pointSize: ScreenTools.smallFontPixelHeight
                    color: "white"
                    z:1000
                }*/
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Flight Time"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "00.00.00"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: dist2HomeArea
            anchors.top: flightTimeArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Dist. to Home"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   _activeVehicle.distanceToHome.value === "NaN"? 0 : _activeVehicle.distanceToHome.value+"m"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: dist2WaypointArea
            anchors.top: dist2HomeArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenterhttps
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   " Dist. to WP"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   _activeVehicle.distanceToNextWP.value == "NaN"? 0 : _activeVehicle.distanceToNextWP.value+"m"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: altitudeRelativeArea
            anchors.top: dist2WaypointArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Altitude Relative"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   Math.round(_activeVehicle.altitudeRelative.value*10)/10 + "m"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: altitudeBarometricArea
            anchors.top: altitudeRelativeArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Altitude (AMSL)"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   Math.round(_activeVehicle.altitudeAMSL.value*10)/10 + "m"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: horSpeedArea
            anchors.top: altitudeBarometricArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Hor. speed"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   Math.round(_activeVehicle.airSpeed.value*10)/10 +"m/s"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }
        Item{
            id: vertSpeedArea
            anchors.top: horSpeedArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: (parent.height -bottomDataArea.height)/6
            ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing:                0
                    height: (parent.height -bottomDataArea.height)/6

                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   "Vert. speed"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
                    Text {
                        Layout.alignment:       Qt.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        color:                  "White"
                        text:                   Math.round(_activeVehicle.climbRate.value*10)/10+"m/s"
                        font.pointSize:         ScreenTools.smallFontPixelHeight
                        font.bold: true
                    }
            }
        }

        Text {
                id: minSpeedText
                text: "Min Speed: 0km/h"
                anchors.left: parent.left
                anchors.bottom: maxSpeedText.top
                anchors.margins: _toolsMargin // Adiciona um pequeno espaço do canto
                font.bold: true
                color: "white"
                z:1000
            }
        Text {
                id: maxSpeedText
                text: "Max Speed: 61,2km/h"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: _toolsMargin // Adiciona um pequeno espaço do canto
                font.bold: true
                color: "white"
                z:1000
            }


        QGCColoredImage {
               id: aircraftIcon
               anchors.top:        parent.bottom
               anchors.left:       parent.left
               //anchors.verticalCenter: parent.verticalCenter
               //anchors.margins:    _toolsMargin
               width:              parent.width
               height:             width
               source:             "/qmlimages/GD25.png"
               fillMode:           Image.PreserveAspectFit
               color:              "white"

                   /*Rectangle {
                       id:rotor1ColorRect
                       x: parent.width*0.05
                       y: parent.height*1/15
                       width: parent.width/2//*10/64
                       height: width/5
                       rotation:-30
                       //radius: width / 2
                       border.width: _selected_rotor_3? 3:1
                       border.color: _selected_rotor_3? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                       visible: false
                   }
                   ColorOverlay{
                   anchors.fill:rotor1ColorRect
                   source:aircraftIcon
                   color:"green"
                   }
                   Rectangle {
                       x: parent.width*0.635
                       y: parent.height*1/24
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       border.width: _selected_rotor_5? 3:1
                       border.color: _selected_rotor_5? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*(-0.025)
                       y: parent.height*0.425
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       border.width: _selected_rotor_2? 3:1
                       border.color: _selected_rotor_2? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.855
                       y: parent.height*0.425
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       border.width: _selected_rotor_1? 3:1
                       border.color: _selected_rotor_1? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.195
                       y: parent.height*0.8
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       border.width: _selected_rotor_6? 3:1
                       border.color: _selected_rotor_6? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.635
                       y: parent.height*0.8
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       border.width: _selected_rotor_4? 3:1
                       border.color: _selected_rotor_4? "yellow":"black"
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }*/
            }
        QGCColoredImage{
            id:rotor1Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor1mask.png"
            color: "white"//_selected_rotor_1 ? "yellow" : "white"  //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor1Mask
                source: rotor1Mask
                color: "yellow" // Semi-transparent black shadow
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_1
            }
        QGCColoredImage{
            id:rotor2Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor2mask.png"
            color: "white"//_selected_rotor_2 ? "yellow" : "white" //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor2Mask
                source: rotor2Mask
                color: "yellow" // yellow selected border
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_2
            }
        QGCColoredImage{
            id:rotor3Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor3mask.png"
            color: "white"//_selected_rotor_3 ? "yellow" : "white"  //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor3Mask
                source: rotor3Mask
                color: "yellow" // yellow selected border
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_3
            }
        QGCColoredImage{
            id:rotor4Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor4mask.png"
            color: "white"//_selected_rotor_4 ? "yellow" : "white"  //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor4Mask
                source: rotor4Mask
                color: "yellow" // yellow selected border
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_4
            }
        QGCColoredImage{
            id:rotor5Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor5mask.png"
            color: "white"//_selected_rotor_5 ? "yellow" : "white"  //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor5Mask
                source: rotor5Mask
                color: "yellow" // yellow selected border
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_5
            }
        QGCColoredImage{
            id:rotor6Mask
            anchors.fill: aircraftIcon
            source: "/qmlimages/rotor6mask.png"
            color: "white"//_selected_rotor_6 ? "yellow" : "white"  //TODO: Mudar isso aqui pra depender da aceleração do rotor
        }
        DropShadow {
                anchors.fill: rotor6Mask
                source: rotor6Mask
                color: "yellow" // yellow selected border
                radius: 8
                samples:17
                spread: 0.4
                verticalOffset: 0
                horizontalOffset: 0
                visible: _selected_rotor_6
            }


    }


//**************************************************************************************************//
//                          MAIN VIEW AREA                                                          //
//**************************************************************************************************//
    Item {
        id: mainViewArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: lateralDataArea.left
        anchors.bottom: bottomDataArea.top

        QGCToolInsets {
            id:                     _toolInsets
            leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
            bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
        }

        FlyViewToolBar {
            id:         toolbar
            visible:    !QGroundControl.videoManager.fullScreen
        }



        Item {
            id:                 mapHolder
            anchors.top:        toolbar.bottom
            anchors.bottom:     parent.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right


            FlyViewMap {
                id:                     mapControl
                planMasterController:   _planController
                rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
                pipView:                _pipView
                pipMode:                !_mainWindowIsMap
                toolInsets:             customOverlay.totalToolInsets
                mapName:                "FlightDisplayView"
                enabled:                !viewer3DWindow.isOpen
            }

            FlyViewVideo {
                id:         videoControl
                pipView:    _pipView
                Rectangle{ //exemplo interface maximizada
                    x:0
                    y:0
                    width: 50
                    height:50
                    color: _mainWindowIsMap? "yellow" : "green"
                }
            }

            PipView {
                id:                     _pipView
                anchors.left:           parent.left
                anchors.bottom:         parent.bottom
                anchors.margins:        _toolsMargin
                item1IsFullSettingsKey: "MainFlyWindowIsMap"
                item1:                  mapControl
                item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
                show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                            (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
                z:                      QGroundControl.zOrderWidgets

                property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
                property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0

                Item{
                    id: cameraExchangeArea
                    height: parent.height/4
                    width: parent.width/8
                    anchors.right: parent.right
                    anchors.bottom:  parent.bottom
                    visible: _pipView._isExpanded || _pipView.isMouseHovered

                    Rectangle {
                            id: _cameraExchangeButton
                            anchors.fill: parent
                            color:"#AA000000"
                            visible: true
                    }
                    RadioComponentController {
                        id:             controller
                        statusText:     statusText
                        cancelButton:   cancelButton
                        nextButton:     nextButton
                        skipButton:     skipButton
                        onChannelCountChanged:              updateChannelCount()
                    }



                    Image {
                        // botão para trocar câmera
                        id: cameraImage
                        anchors.centerIn: parent // Center the image in the parent
                        width: parent.width * 0.9 // 90% of parent's width
                        height: parent.height * 0.9 // 90% of parent's height
                        fillMode: Image.PreserveAspectFit
                        source: "/qmlimages/camera"
                        visible: _pipView._isExpanded // && _pipView._isMouseHovered
                    }
                        MouseArea {
                           id: click_trocar_camera
                           z: _cameraExchangeButton.z
                           anchors.fill: cameraImage
                           hoverEnabled: true
                           onClicked : {
                               _cameraExchangeActive = !_cameraExchangeActive
                               console.log(_pipView._isExpanded)
                           }
                        }
                }
                Item {
                    x:_cameraExchangeButton.x
                    y:_cameraExchangeButton.y
                    z:_cameraExchangeButton.z+100
                    visible: _cameraExchangeActive && _pipView._isExpanded

                    GridLayout {
                        id:         videoGrid
                        columns:    1

                        FactComboBox{
                            id:                     videoSource
                            Layout.preferredWidth:  _comboFieldWidth
                            indexModel:             false
                            fact:                   QGroundControl.settingsManager.videoSettings.videoSource
                        }
                    }
                }


            }


            FlyViewWidgetLayer {
                id:                     widgetLayer
                anchors.top:            parent.top
                anchors.bottom:         parent.bottom
                anchors.left:           parent.left
                anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
                z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
                parentToolInsets:       _toolInsets
                mapControl:             _mapControl
                visible:                !QGroundControl.videoManager.fullScreen
                utmspActTrigger:        utmspSendActTrigger
                isViewer3DOpen:         viewer3DWindow.isOpen
            }

            FlyViewCustomLayer {
                id:                 customOverlay
                anchors.fill:       widgetLayer
                z:                  _fullItemZorder + 2
                parentToolInsets:   widgetLayer.totalToolInsets
                mapControl:         _mapControl
                visible:            !QGroundControl.videoManager.fullScreen
            }

            // Development tool for visualizing the insets for a paticular layer, show if needed
            FlyViewInsetViewer {
                id:                     widgetLayerInsetViewer
                anchors.top:            parent.top
                anchors.bottom:         parent.bottom
                anchors.left:           parent.left
                anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
                z:                      widgetLayer.z + 1
                insetsToView:           widgetLayer.totalToolInsets
                visible:                false
            }

            GuidedActionsController {
                id:                 guidedActionsController
                missionController:  _missionController
                actionList:         _guidedActionList
                guidedValueSlider:     _guidedValueSlider
            }

            GuidedActionList {
                id:                         guidedActionList
                anchors.margins:            _margins
                anchors.bottom:             parent.bottom
                anchors.horizontalCenter:   parent.horizontalCenter
                z:                          QGroundControl.zOrderTopMost
                guidedController:           _guidedController
            }

            //-- Guided value slider (e.g. altitude)
            GuidedValueSlider {
                id:                 guidedValueSlider
                anchors.margins:    _toolsMargin
                anchors.right:      parent.right
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                z:                  QGroundControl.zOrderTopMost
                visible:            false
            }

            Viewer3D{
                id:                     viewer3DWindow
                anchors.fill:           parent
            }
        }
    }
}
