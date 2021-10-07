Shader "BlackHole"
{
    Properties
    {
        [NoScaleOffset] _SkyBoxTex ("SkyBox Cube Texture", Cube) = "white" {}
        [NoScaleOffset] _AccretionDiskTex ("Accretion Disk Texture", 2D) = "white" {}
        _AccretionDiskBright ("Accretion Disk Bright", Range(0.5, 4)) = 1.5
        _AccretionDiskWidth ("Accretion Disk Width", Range(2.5, 8)) = 8
        _AccretionDiskSpeed ("Accretion Disk Speed", Range(-64, 64)) = 2
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                fixed4 vertex : POSITION;
                fixed2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                fixed4 vertex : SV_POSITION;
                fixed3 rayDir : TEXCOORD0;
            };


            samplerCUBE _SkyBoxTex;
            half4 _SkyBoxTex_HDR;
            sampler2D _AccretionDiskTex;
            fixed _AccretionDiskBright;
            fixed _AccretionDiskWidth;
            fixed _AccretionDiskSpeed;


            fixed eventHorizon(fixed3 pPosition)
            {
                return length(pPosition) - 1;
            }


            fixed3 accretionDisk(fixed3 pPosition)
            {
                const fixed MIN_WIDTH = 2.6; // 由于引力透镜，事件视界看起来是没有引力透镜的2.6倍

                fixed r = length(pPosition);

                fixed3 disk = fixed3(_AccretionDiskWidth, 0.1, _AccretionDiskWidth); // 视作一个压扁的球
                if (length(pPosition / disk) > 1)
                {
                    return fixed3(0, 0, 0);
                }
                fixed temperature = max(0, 1 - length(pPosition / disk));
                temperature *= (r - MIN_WIDTH) / (_AccretionDiskWidth - MIN_WIDTH);
                // 坐标转换为球极坐标系
                fixed t = atan2(pPosition.z, pPosition.x); // θ
                fixed p = asin(pPosition.y / r); // φ
                fixed3 sphericalCoord = fixed3(r, t, p);
                fixed noise = 0;
                // 使用两层噪声叠加出云的纹理
                UNITY_LOOP
                for (int i = 1; i < 4; i++)
                {
                    fixed2 noiseUV;
                    fixed speedFactor;
                    if(i % 2 == 0) // 云和环状效果
                    {
                        noiseUV = sphericalCoord.xy;
                        speedFactor = 1;
                    }
                    else
                    {
                        noiseUV = sphericalCoord.xz;
                        speedFactor = -1;
                    }
                    noise += tex2D(_AccretionDiskTex, noiseUV * pow(i, 3)).r;
                    sphericalCoord.y += _AccretionDiskSpeed * _Time.x * speedFactor;
                }
                // 橙红色作为吸积盘颜色
                fixed3 color = fixed3(1, 0.5, 0.4);
                return temperature * noise * color * _AccretionDiskBright;
            }


            fixed3 gravitationalLensing(fixed pH2, fixed3 pPosition)
            {
                fixed r2 = dot(pPosition, pPosition);
                fixed r5 = pow(r2, 2.5);
                return -1.5 * pH2 * pPosition / r5;
            }


            v2f vert (appdata i)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(i.vertex);
                // 变换得到屏幕四个角向外的射线
                fixed3 dir = mul(unity_CameraInvProjection, fixed4(i.uv * 2.0f - 1.0f, 0.0f, -1.0f));
                o.rayDir = normalize(mul(unity_CameraToWorld, fixed4(dir, 0.0f)));
                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                const fixed step = 0.1; // 步进长度，太大会有横纹

                fixed3 checkPos = _WorldSpaceCameraPos;
                fixed3 dir = i.rayDir * step;

                fixed3 color = fixed3(0, 0, 0);

                fixed3 h = cross(checkPos, dir);
                fixed h2 = dot(h, h);

                UNITY_LOOP
                for (int i = 0; i < 300; i++)
                {
                    // 事件视界
                    if (eventHorizon(checkPos) < 0)
                    {
                        return fixed4(color, 1);
                    }
                    
                    // 吸积盘
                    color += accretionDisk(checkPos);

                    // 引力透镜
                    fixed3 offset = gravitationalLensing(h2, checkPos);
                    dir += offset;
                    
                    // 步进
                    checkPos += dir;
                }

                // 天空盒
                fixed4 skyBox = texCUBE(_SkyBoxTex, dir);
                color += DecodeHDR(skyBox, _SkyBoxTex_HDR).rgb;

                return fixed4(color, 1);
            }
            ENDCG
        }
    }
}
