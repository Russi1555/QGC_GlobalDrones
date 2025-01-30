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
    property var _tensao_bateria: _activeVehicle? 9 : 0
    property var _current_bateria: _activeVehicle? 9 : 0
    property var _current_generator: 0
    property real _gasolina: _activeVehicle.batteries.get(1).percentRemaining.rawValue
    property int _satCount: 0
    property int _satPDOP: 0
    property int _rcQuality: 0
    property var _current_battery_ARRAY: []
    property var _current_generator_ARRAY: []
    property var _returnFunctionArray: []
    property bool flagAlertaGerador: false
    property real oldGeneratorMediamValue: 0
    property var  _distanceToHome:     _activeVehicle.distanceToHome.rawValue
    property var  _distanceToWP: _activeVehicle.distanceToNextWP.rawValue

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

    property real _temperatura_rotor_1: 50 //PLACEHOLDER
    property real _temperatura_rotor_2: 45 //PLACEHOLDER
    property real _temperatura_rotor_3: 70 //PLACEHOLDER
    property real _temperatura_rotor_4: 20 //PLACEHOLDER
    property real _temperatura_rotor_5: 80 //PLACEHOLDER
    property real _temperatura_rotor_6: 50 //PLACEHOLDER


    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets



    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMessageIndicatorTool() {
        toolbar.dropMessageIndicatorTool();
    }

    function generatorAlert(batValues, gerValues, oldGerMed){
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
        }

        return [flagAlert, medGer];
    }

    Timer{
        id: propertyValuesUpdater
        interval: 100
        running: true
        repeat: true
        onTriggered:{
            _pct_bateria = _activeVehicle.batteries.get(0).percentRemaining.rawValue
            _satCount = _activeVehicle.gps.count.rawValue
            _satPDOP = _activeVehicle.gps.lock.rawValue

            //Monitoramento do gerador
            _current_battery_ARRAY.push(_current_bateria) //populando dinamicamente array de valores de corrente da bateria
            _current_generator_ARRAY.push(_current_generator)//populando dinamicamente array de valores de corrente do gerador
            if(_current_generator_ARRAY.length === 20){ //sabendo que recebemos um dado novo a cada 0.1 segundos, (ver c/ Erich)
                _returnFunctionArray = generatorAlert(_current_battery_ARRAY, _current_generator_ARRAY, oldGeneratorMediamValue);//executa função
                flagAlertaGerador = _returnFunctionArray[0]; //atualiza flag geral com valor booleano retornado da função
                oldGeneratorMediamValue = _returnFunctionArray[1]; //atualiza valor de média
                _current_battery_ARRAY.shift(); //apaga primeiro elemento (ver c/Erich se é pra apagar o primeiro elemento ou todos)
                _current_generator_ARRAY.shift();
                //console.log(_current_battery_ARRAY);
                //console.log(_current_generator_ARRAY);
            }
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


            }

        ColumnLayout {
                id:                     batteryInfoColumn
                anchors.top: parent.top
                anchors.left: batteryPercentageIcon.right
                spacing:                0

                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   _pct_bateria > 9? _pct_bateria+"%": "0"+_pct_bateria+"%"
                    font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   (_tensao_bateria/100) + " V"
                    font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   (_current_bateria/100) + " mA"
                    font.pointSize:         ScreenTools.mediumFontPixelHeight
                }

            }

        Rectangle {
               id: cellsTensionArea
               anchors.top: parent.top
               anchors.left: batteryInfoColumn.right
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

           }

        Rectangle{
                id: gasolinePercentageBar
                anchors.top: gasolinePercentageIcon.top
                anchors.left: gasolinePercentageIcon.right
                //anchors.margins: _toolsMargin
                width: gasolinePercentageIcon.width/3
                height: parent.height*2/3
                color: gasMouseArea.containsMouse? "green": "red"

                MouseArea{
                    id: gasMouseArea
                    anchors.fill: parent
                    hoverEnabled : true

                }

                Rectangle{
                     anchors.top: parent.top
                     anchors.left: parent.left
                     width: parent.width
                     height: parent.height*(0.3) // dinamico de acordo com 1-(% gasolina). cor há de ser dinamica também
                     color: "black"
                }

                Rectangle{
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "lightgray"
                }

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
               color:              "white"
            }

        //satelite https://forest-gis.com/2018/01/acuracia-gps-o-que-sao-pdop-hdop-gdop-multi-caminho-e-outros.html/?srsltid=AfmBOorX7DD9JggA1vLTP2DuhOK44T28jHasCbLA0nv5nSnLX7irYLlW
        //activeVehicle.gps.count.rawValue (NUM SATELITES); _activeVehicle.gps.hdop.rawValue (HDOP); globals.activeVehicle.gps.lock.rawValue (PDOP)
        QGCColoredImage {
               id: satteliteInformationIcon
               anchors.top:        parent.top
               anchors.left:       generatorFunctionalityIcon.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/Gps.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }

        ColumnLayout {
                id:                     satteliteInfoColumn
                anchors.top: parent.top
                anchors.left: satteliteInformationIcon.right
                spacing:                0

                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "Count: " + _satCount
                    font.pointSize:         ScreenTools.mediumFontPixelHeight
                }
                Text {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  "White"
                    text:                   "PDOP: "+ _satPDOP
                    font.pointSize:         ScreenTools.mediumFontPixelHeight
                }

            }

        //enlace
        QGCColoredImage {
               id: rcInformationIcon
               anchors.top:        parent.top
               anchors.left:       satteliteInfoColumn.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/RC.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }
        Rectangle{
                id: rcQualityBar
                anchors.top: parent.top
                anchors.left: rcInformationIcon.right
                anchors.margins: _toolsMargin
                width: rcInformationIcon.width/3
                height: parent.height*2/3
                color: rcMouseArea.containsMouse? "green": "red"

                MouseArea{
                    id: rcMouseArea
                    anchors.fill: parent
                    hoverEnabled : true

                }

                Rectangle{
                     anchors.top: parent.top
                     anchors.left: parent.left
                     width: parent.width
                     height: parent.height*(0.3) // dinamico de acordo com 1-(% RC). cor há de ser dinamica também. Ver como pegar esse valor
                     color: "black"
                }

                Rectangle{
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "lightgray"
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
        Rectangle{
                id: motorTemperatureBar
                anchors.top: parent.top
                anchors.left: motorTemperatureInformationIcon.right
                anchors.margins: _toolsMargin
                width: motorTemperatureInformationIcon.width/3
                height: parent.height*2/3
                color: motorTemperatureMouseArea.containsMouse? "green": "red"

                MouseArea{
                    id: motorTemperatureMouseArea
                    anchors.fill: parent
                    hoverEnabled : true

                }

                Rectangle{
                     anchors.top: parent.top
                     anchors.left: parent.left
                     width: parent.width
                     height: parent.height*(0.3) // dinamico de acordo com temperatura do motor (esperar essa informação ficar disponível)
                     color: "black"
                }

                Rectangle{
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "lightgray"
                }

           }

        //Temperatura Rotores
        QGCColoredImage {
               id: rotorTemperatureInformationIcon
               anchors.top:        parent.top
               anchors.left:       motorTemperatureBar.right
               anchors.margins:    _toolsMargin*2
               width:              height
               height:             parent.height*2/3
               source:             "/qmlimages/RotorsTemp.svg"
               fillMode:           Image.PreserveAspectFit
               color:              "white"
            }
        Rectangle {
               id: rotorsTempArea
               anchors.top: parent.top
               anchors.left: rotorTemperatureInformationIcon.right
               anchors.margins: _toolsMargin * 1.5
               width: height * 2
               height: rotorTemperatureInformationIcon.height
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
                       id: tempRotorModel
                   }

                   // Popula o modelo com valores dinamicamente
                   Component.onCompleted: {
                       tempRotorModel.append({ temperatura: _temperatura_rotor_1 });
                       tempRotorModel.append({ temperatura: _temperatura_rotor_2 });
                       tempRotorModel.append({ temperatura: _temperatura_rotor_3 });
                       tempRotorModel.append({ temperatura: _temperatura_rotor_4 });
                       tempRotorModel.append({ temperatura: _temperatura_rotor_5 });
                       tempRotorModel.append({ temperatura: _temperatura_rotor_6 });

                   }

                   Timer{//Atualiza os valores periodicamente [TODO: mudar interval depois]
                        interval: 10000; running: true; repeat: true
                        onTriggered: {
                        tempRotorModel.set(0, { temperatura: _temperatura_rotor_1 });
                        tempRotorModel.set(1, { temperatura: _temperatura_rotor_2 });
                        tempRotorModel.set(2, { temperatura: _temperatura_rotor_3 });
                        tempRotorModel.set(3, { temperatura: _temperatura_rotor_4 });
                        tempRotorModel.set(4, { temperatura: _temperatura_rotor_5 });
                        tempRotorModel.set(5, { temperatura: _temperatura_rotor_6 });
                       }
                    }

                   Repeater {
                       model: tempRotorModel

                       Rectangle {
                           width: parent.width / 6
                           height: model.temperatura // Altura proporcional à temperatura
                           x: index * parent.width / 6 // Posiciona horizontalmente
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

                               }
                           }
                       }
                    }

           }


    }

//**************************************************************************************************//
//                          LATERAL VIEW AREA                                                       //
//**************************************************************************************************//
    Item {
        id: lateralDataArea
        anchors.right : parent.right
        anchors.bottom : lateralDataArea.top
        width : parent.width - mainViewWidth
        height: mainViewHeight
        //Ilustração Aeronave {EXPERIMENTAR COLOCAR NO FUNDO DO LATERAL VIEW AREA PRA MANTER CENTRALIZAÇÃO HORIZONTAL}
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
               z:1000
               // Add a circle on top of the image
                   Rectangle {
                       x: parent.width*0.195
                       y: parent.height*1/24
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.635
                       y: parent.height*1/24
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*(-0.025)
                       y: parent.height*0.425
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.855
                       y: parent.height*0.425
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.195
                       y: parent.height*0.8
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
                   Rectangle {
                       x: parent.width*0.635
                       y: parent.height*0.8
                       width: parent.width*10/64
                       height: width
                       radius: width / 2
                       color:  Qt.rgba(1, 0, 0, 0.5)
                       z: 1100
                   }
            }


        Rectangle {
                anchors.fill: parent
                color:qgcPal.toolbarBackground
                //gradient: Gradient {
                //    GradientStop { position: 0.7; color:  qgcPal.toolbarBackground} // Top color
                //    GradientStop { position: 1.0; color:  toolbar._mainStatusBGColor} // Bottom color
                //}
            }
    }


//**************************************************************************************************//
//                          MAIN VIEW AREA                                                          //
//**************************************************************************************************//
    Item {
        id: mainViewArea
        anchors.top: parent.top
        anchors.left: parent.left
        height: mainViewHeight
        width : mainViewWidth

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
