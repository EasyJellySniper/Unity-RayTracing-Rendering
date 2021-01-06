using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// editor camera controller
/// </summary>
public class SceneCameraControl : MonoBehaviour
{
    /// <summary>
    /// cursor texture
    /// </summary>
    [Header("游標圖示")]
    public Texture2D cursor = null;
    /// <summary>
    /// mouse sensitivity
    /// </summary>
    [Header("滑鼠靈敏度"), Range(1, 10)]
    public int mouseSensitivity = 5;
    /// <summary>
    /// camera move speed
    /// </summary>
    [Header("移動速度"), Range(1, 100)]
    public int moveSpeed = 5;

    [Header("模擬車輛視野:")]
    /// <summary>
    /// 鏡頭高度
    /// </summary>
    public float camHight = 1.7f;

    /// <summary>
    /// 設成車輛第三人稱視野
    /// </summary>
    public bool setToVehicleView = false;

    float rotationX = 0.0f;
    float rotationY = 0.0f;
    Quaternion originalRotation;
    Vector3 transition;
    float moveDistance;

    public static float ClampAngle360(float _angle)
    {
        float ret = _angle;
        while (ret > 360.0f)
        {
            ret -= 360.0f;
        }
        while (ret < -360.0f)
        {
            ret += 360.0f;
        }
        return ret;
    }

    void Update()
    {
        const float MoveSpeedScale = 5.0f;
        moveDistance = (float)moveSpeed * MoveSpeedScale * Time.unscaledDeltaTime;
        transition = Vector3.zero;

        if (Input.GetKey(KeyCode.A))
        {
            transition += -transform.right * moveDistance;
        }
        if(Input.GetKey(KeyCode.D))
        {
            transition += transform.right * moveDistance;
        }
        if(Input.GetKey(KeyCode.W))
        {
            transition += transform.forward * moveDistance;
        }
        if(Input.GetKey(KeyCode.S))
        {
            transition += -transform.forward * moveDistance;
        }
        if (Input.GetKey(KeyCode.E))
        {
            transition += transform.up * moveDistance;
        }
        if (Input.GetKey(KeyCode.Q))
        {
            transition += -transform.up * moveDistance;
        }

        const float SensitivityScale = 20.0f;
        if (Input.GetMouseButton(1))
        {
            rotationY += Input.GetAxis("Mouse Y") * (float)mouseSensitivity * SensitivityScale * Time.unscaledDeltaTime;
            rotationX += Input.GetAxis("Mouse X") * (float)mouseSensitivity * SensitivityScale * Time.unscaledDeltaTime;

            rotationX = ClampAngle360(rotationX);
            rotationY = Mathf.Clamp(rotationY, -89.0f, 89.0f);

            Quaternion yQuaternion = Quaternion.AngleAxis(rotationY, Vector3.left);
            Quaternion xQuaternion = Quaternion.AngleAxis(rotationX, Vector3.up);

            transform.localRotation = originalRotation * xQuaternion * yQuaternion;

            Cursor.SetCursor(cursor, new Vector2(32.0f, 32.0f), CursorMode.Auto);
        }
        else
        {
            Cursor.SetCursor(null, new Vector2(32.0f, 32.0f), CursorMode.Auto);
        }

        transform.localPosition += transition;
    }

    void Start()
    {
        originalRotation = transform.localRotation;
    }

    void SetToVehicleView()
    {
#if UNITY_EDITOR
        var sceneCam = UnityEditor.SceneView.lastActiveSceneView.camera;
        var sceneCamPos = sceneCam.transform.position;
        var hitInfo1 = new RaycastHit();
        var hitInfo2 = new RaycastHit();

        Physics.Raycast(sceneCamPos, Vector3.down, out hitInfo1, 300f);
        Physics.Raycast(sceneCamPos + sceneCam.transform.forward, Vector3.down, out hitInfo2, 300f);

        transform.up = hitInfo1.normal;

        var hight = camHight - hitInfo1.distance;
        transform.position = new Vector3(sceneCamPos.x, sceneCamPos.y + hight, sceneCamPos.z);

        //transform.forward = sceneCam.transform.forward;
        transform.LookAt(hitInfo1.point + (hitInfo2.point - hitInfo1.point).normalized * 30);

        var gameCam = transform.GetComponent<Camera>();
        if(gameCam)
        {
            gameCam.fieldOfView = 65;
        }
#endif
    }
}
