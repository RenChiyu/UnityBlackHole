using UnityEngine;


[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public class BlackHole : MonoBehaviour
{
    private Material m_Mat;


    private void Start()
    {
        this.m_Mat = Resources.Load<Material>("BlackHole");
    }


    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        var tempTex = RenderTexture.GetTemporary(source.width, source.height);
        Graphics.Blit(source, tempTex, this.m_Mat, 0);
        Graphics.Blit(tempTex, destination);
        RenderTexture.ReleaseTemporary(tempTex);
    }
}