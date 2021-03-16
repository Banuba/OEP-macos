function Effect()
{
    this.init = function() {
        Api.meshfxMsg("spawn", 0, 0, "tri.bsm2");
        Api.meshfxMsg("shaderVec4", 0, 0, "0.3 1. 0.7 1.");
        Api.showRecordButton();
    };
    this.faceActions = [];
    this.noFaceActions = [];
    this.videoRecordStartActions = [];
    this.videoRecordFinishActions = [];
    this.videoRecordDiscardActions = [];
}

function setColor(color) {
    var c = JSON.parse(color);
    Api.meshfxMsg("shaderVec4", 0, 0, c[0] + " " + c[1] + " " + c[2] + " " + c[3]);
}

configure(new Effect());