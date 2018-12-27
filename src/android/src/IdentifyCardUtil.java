package com.gsst.cordova.util;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;
import android.util.Base64;
import android.util.DisplayMetrics;
import android.util.Log;
import android.widget.Toast;
import android.bluetooth.BluetoothAdapter;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.apache.cordova.PluginResult;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;

import cn.com.senter.helper.ShareReferenceSaver;
import cn.com.senter.sdkdefault.helper.Error;
import cn.com.senter.helper.ConsantHelper;

public class IdentifyCardUtil extends CordovaPlugin {

    private BluetoothAdapter mBluetoothAdapter = null;
    private BlueReaderHelper mBlueReaderHelper;
    private String Blueaddress = null;

    public Activity activity;
    public Context content;
    public CallbackContext callback_context;
    private String Server_sel;
    public static Handler uiHandler;
    private final static String Server_Selected = "CN.COM.SENTER.SelIndex";
    private final static String SERVER_KEY1 = "CN.COM.SENTER.SERVER_KEY1";
    private final static String PORT_KEY1 = "CN.COM.SENTER.PORT_KEY1";
    private final static String SERVER_KEY2 = "CN.COM.SENTER.SERVER_KEY2";
    private final static String PORT_KEY2 = "CN.COM.SENTER.PORT_KEY2";

    private final static String SERVER_KEY3 = "CN.COM.SENTER.SERVER_KEY3";
    private final static String PORT_KEY3 = "CN.COM.SENTER.PORT_KEY3";
    private String server_address = "";
    private final static String SERVER_KEY4 = "CN.COM.SENTER.SERVER_KEY4";
    private final static String PORT_KEY4 = "CN.COM.SENTER.PORT_KEY4";

    private final static String BLUE_ADDRESSKEY = "CN.COM.SENTER.BLUEADDRESS";
    private final static String KEYNM = "CN.COM.SENTER.KEY";
    private int server_port = 0;
    private int totalcount ;
    private int failecount;
    private JSONObject jsonCallbackResult;

    private AsyncTask<Void, Void, String> nfcTask = null;


    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) throws JSONException {
        activity = cordova.getActivity();
        content = cordova.getActivity().getApplicationContext();
        callback_context = callbackContext;
        totalcount = 0;
        failecount = 0 ;

        if("getMessage".equals(action)){
            //connect blue tooth
            mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
            if (mBluetoothAdapter == null) {
                Toast.makeText(activity, "Bluetooth is not available", Toast.LENGTH_LONG).show();

                return false;
            }
            if (!mBluetoothAdapter.isEnabled()) {
                Toast.makeText(activity, "请打开蓝牙", Toast.LENGTH_LONG).show();
                return false ;
            }

//            if (mBluetoothAdapter.getScanMode() != BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE) {
//                Intent i = new Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE);
//                //设置为一直开启
//                i.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 0);
//            }
//            mBluetoothAdapter.startDiscovery() ;
//
//            Set<BluetoothDevice> pairedDevices = mBluetoothAdapter.getBondedDevices();
//            if (pairedDevices.size() > 0) {
//                for (BluetoothDevice device : pairedDevices) {
//                    String deviceName = device.getName() ;
//                    if(deviceName.contains("ST")){
//                        Blueaddress = device.getAddress() ;
//                        break;
//                    }
//                }
//                mBluetoothAdapter.cancelDiscovery() ;
//            }
            Blueaddress = args.getString(0) ;


            uiHandler = new MyHandler(activity);

            mBlueReaderHelper = new BlueReaderHelper(activity, uiHandler);

            initShareReference();

            if ( Blueaddress == null){
                Toast.makeText(activity, "请选择蓝牙设备，再读卡!", Toast.LENGTH_LONG).show();
                return false ;
            }



            if ( Blueaddress.length() <= 0){
                Toast.makeText(activity, "请选择蓝牙设备，再读卡!", Toast.LENGTH_LONG).show();
                return false;
            }

            // get identifyCare message
            if(mBlueReaderHelper.registerBlueCard(Blueaddress) ){
                new BlueReadTask()
                        .executeOnExecutor(Executors.newCachedThreadPool());
            }
        };
        return true;
    }




    private void initShareReference() {

        if (ShareReferenceSaver.getData(activity, Server_Selected).trim().length() < 1) {
            this.Server_sel = "0";
        } else {
            this.Server_sel = ShareReferenceSaver.getData(activity, Server_Selected);
        }

        if ( this.server_address.length() <= 0){
            if (Server_sel.equals("0")) {
                if (ShareReferenceSaver.getData(activity, SERVER_KEY1).trim().length() <= 0) {
                    this.server_address = "senter-online.cn";
                } else {
                    this.server_address = ShareReferenceSaver.getData(activity, SERVER_KEY1);
                }
                if (ShareReferenceSaver.getData(activity, PORT_KEY1).trim().length() <= 0) {
                    this.server_port = 10002;
                } else {
                    this.server_port = Integer.valueOf(ShareReferenceSaver.getData(activity, PORT_KEY1));
                }
            }
            if (Server_sel.equals("1")) {
                if (ShareReferenceSaver.getData(activity, SERVER_KEY2).trim().length() <= 0) {
                    this.server_address = "senter-online.cn";
                } else {
                    this.server_address = ShareReferenceSaver.getData(activity, SERVER_KEY2);
                }
                if (ShareReferenceSaver.getData(activity, PORT_KEY2).trim().length()<= 0) {
                    this.server_port = 10002;
                } else {
                    this.server_port = Integer.valueOf(ShareReferenceSaver.getData(activity, PORT_KEY2));
                }
            }
            if (Server_sel.equals("2")) {
                if (ShareReferenceSaver.getData(activity, SERVER_KEY3).trim().length() <= 0) {
                    this.server_address = "senter-online.cn";
                } else {
                    this.server_address = ShareReferenceSaver.getData(activity, SERVER_KEY3);
                }
                if (ShareReferenceSaver.getData(activity, PORT_KEY3).trim().length() <= 0) {
                    this.server_port = 10002;
                } else {
                    this.server_port = Integer.valueOf(ShareReferenceSaver.getData(activity, PORT_KEY3));
                }
            }
            if (Server_sel.equals("3")) {
                if (ShareReferenceSaver.getData(activity, SERVER_KEY4).trim().length() <= 0) {
                    this.server_address = "senter-online.cn";
                } else {
                    this.server_address = ShareReferenceSaver.getData(activity, SERVER_KEY4);
                }
                if (ShareReferenceSaver.getData(activity, PORT_KEY4).trim().length() <= 0) {
                    this.server_port = 10002;
                } else {
                    this.server_port = Integer.valueOf(ShareReferenceSaver.getData(activity, PORT_KEY4));
                }
            }
        }


        //----实例化help类---
        mBlueReaderHelper.setServerAddress(this.server_address);
        mBlueReaderHelper.setServerPort(this.server_port);
    }



    class MyHandler extends Handler {
        private Activity activity;

        MyHandler(Activity activity) {
            this.activity = activity;
        }

        @Override
        public void handleMessage(Message msg) {

            switch (msg.what) {
                case ConsantHelper.READ_CARD_SUCCESS:

                    break;

                case ConsantHelper.SERVER_CANNOT_CONNECT:
                    jsonCallbackResult = createResultJson(false, null, "服务器连接失败! 请检查网络！");
                    cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                    break;

                case ConsantHelper.READ_CARD_FAILED:
                    jsonCallbackResult = createResultJson(false, null, "无法读取信息请重试！");
                    cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                    break;

                case ConsantHelper.READ_CARD_WARNING:
                    break;

                case ConsantHelper.READ_CARD_PROGRESS:

                    int progress_value = (Integer) msg.obj;

                    Toast.makeText(activity, "正在读卡......", Toast.LENGTH_LONG).show();
                    break;

                case ConsantHelper.READ_CARD_START:

                    Toast.makeText(activity, "正在读卡......", Toast.LENGTH_LONG).show();
                    break;
                case Error.ERR_CONNECT_SUCCESS:
//                    cordova.getThreadPool().execute(new Runnable() {
//                       @Override
//                       public void run() {
//                           String strCardInfo =mBlueReaderHelper.read();
//                       }
//                   });
                    Toast.makeText(activity, "连接成功......", Toast.LENGTH_LONG).show();
                    break;
                case Error.ERR_CONNECT_FAILD:
                    jsonCallbackResult = createResultJson(false, null, "连接失败！");
                    cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                    break;
                case Error.ERR_CLOSE_SUCCESS:

                    Toast.makeText(activity, "断开连接成功......", Toast.LENGTH_LONG).show();
                    break;
                case Error.ERR_CLOSE_FAILD:
                    Toast.makeText(activity, "断开连接失败......", Toast.LENGTH_LONG).show();
                    break;
                case Error.RC_SUCCESS:

                    Toast.makeText(activity, "连接成功!", Toast.LENGTH_LONG).show();

                    break;

            }
        }

    }


    /**
     * 蓝牙读卡方式
     */
    private class BlueReadTask extends AsyncTask<Void, Void, String> {

        @Override
        protected void onPostExecute(String strCardInfo) {

            if (TextUtils.isEmpty(strCardInfo)) {
                uiHandler.sendEmptyMessage(ConsantHelper.READ_CARD_FAILED);
                nfcTask = null;
                failecount++;
                return;
            }

            if (strCardInfo.length() <=2){
                readCardFailed(strCardInfo);
                nfcTask = null;
                failecount++;
                return;
            }

            totalcount++;
            readCardSuccess(strCardInfo);


            nfcTask = null;

            super.onPostExecute(strCardInfo);

        }

        @Override
        protected String doInBackground(Void... params) {

            String strCardInfo =mBlueReaderHelper.read();
            return strCardInfo;
        }
    }

    private void readCardFailed(String strcardinfo){
        int bret = Integer.parseInt(strcardinfo);
        switch (bret){
            case -1:
                jsonCallbackResult = createResultJson(false, null, "服务器连接失败！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case 1:
                jsonCallbackResult = createResultJson(false, null, "读卡失败,请放卡！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case 2:
                jsonCallbackResult = createResultJson(false, null, "读卡失败！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case 3:
                jsonCallbackResult = createResultJson(false, null, "网络超时！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case 4:
                jsonCallbackResult = createResultJson(false, null, "读卡失败！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case -2:
                jsonCallbackResult = createResultJson(false, null, "读卡失败！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
            case 5:
//                Toast.makeText(activity, "照片解码失败!", Toast.LENGTH_LONG).show();
                jsonCallbackResult = createResultJson(false, null, "照片解码失败！");
                cbreturn(PluginResult.Status.OK, jsonCallbackResult);
                break;
        }

    }


    private void readCardSuccess(String strCardInfo) {
        JSONObject result =new JSONObject() ;
        JSONObject jsonObj;

        byte [] avatar = new byte [20 *1024
                ];
//
        try {
//            strCardInfo.substring()
            jsonObj = new JSONObject(strCardInfo);
            result.put("name",jsonObj.getString("name")) ;
            result.put("sex",jsonObj.getString("sex")) ;
            result.put("ethnicity",jsonObj.getString("ethnicity")) ;
            result.put("birth",jsonObj.getString("birth")) ;
            result.put("cardNo",jsonObj.getString("cardNo")) ;
            result.put("authority",jsonObj.getString("authority")) ;
            result.put("address",jsonObj.getString("address")) ;
            result.put("period",jsonObj.getString("period")) ;

            JSONArray javatar = jsonObj.getJSONArray("avatar");
            int len = javatar.length();
            for(int j=0; j< len; j++){
                avatar[j] = (byte) javatar.getInt(j);
            }

        } catch (JSONException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
        }

        try {

            Bitmap bm = BitmapFactory.decodeByteArray(avatar,
                    0, avatar.length);
            ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
            bm.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream);
            byte[] bytes = byteArrayOutputStream.toByteArray();
            byte[] encode = Base64.encode(bytes, Base64.DEFAULT);
            String base64Images = new String(encode) ;

            result.put("photo",base64Images) ;


            Log.e(ConsantHelper.STAGE_LOG, "图片成功");
        } catch (Exception e) {
            jsonCallbackResult = createResultJson(false, result, "图片读取失败！");
        }

        jsonCallbackResult = createResultJson(true, result, "读取成功");


        cbreturn(PluginResult.Status.OK,jsonCallbackResult);
    }

    private JSONObject createResultJson(Boolean status, JSONObject data, String msg){
        JSONObject jsonobjectResult = new JSONObject();
        try {
            jsonobjectResult.put("status", status);
            jsonobjectResult.put("data", data);
            jsonobjectResult.put("message", msg);
        } catch (Exception e){
            jsonobjectResult = createResultJson(false, null, "读卡失败！");
        }

        return jsonobjectResult;
    }

    private void cbreturn(PluginResult.Status status,JSONObject msg){
        PluginResult pluginResult = new PluginResult(status,msg );
        pluginResult.setKeepCallback(true);
        callback_context.sendPluginResult(pluginResult);
    }


}