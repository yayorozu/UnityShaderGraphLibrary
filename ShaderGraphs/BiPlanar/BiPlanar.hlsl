// ------------------------------------------------------------
// Helper : ブレンドウェイト計算
// ２軸方向の正規化された法線成分からブレンド係数を算出する
inline float2 CalcBlendWeights(float3 absNormal, int2 axes, float blendSharpness)
{
    float2 w = float2(absNormal[axes.x], absNormal[axes.y]);
    w = clamp((w - 0.5773) / (1.0 - 0.5773), 0.0, 1.0); // 54.7° = cos^-1(1/√3)
    w = pow(w, float2(blendSharpness * 0.125, blendSharpness * 0.125));
    return w;
}

// ------------------------------------------------------------
// Helper : RNMブレンド
// Reoriented Normal Mapping を用いてタンジェント空間法線を回転させる
inline float3 BlendRNM(float3 n1, float3 n2)
{
    n1.z += 1.0;
    n2.xy = -n2.xy;
    return n1 * dot(n1, n2) / n1.z - n2;
}

// ------------------------------------------------------------
// Helper : タンジェント→ワールド変換
// 指定軸を基準に、サンプリングしたノーマルマップをワールド空間に回転
inline float3 ReorientToWorld(float3 tNormal, int axis, float3 surfNormal)
{
    float3 absN = abs(surfNormal);
    if (axis == 0)
        return BlendRNM(float3(surfNormal.zy, absN.x), tNormal); // X軸基準
    if (axis == 1)
        return BlendRNM(float3(surfNormal.xz, absN.y), tNormal); // Y軸基準
    return BlendRNM(float3(surfNormal.xy, absN.z), tNormal);     // Z軸基準
}

// ------------------------------------------------------------
// Helper : Bi-Planar サンプリングセットアップ
// 指定された法線に応じて2面投影用のUVとブレンド軸を決定し、テクスチャをサンプリング
inline void SetupBiPlanarSample(
    UnityTexture2D Texture,
    UnitySamplerState Sampler,
    float3 PositionWS,
    float3 NormalWS,
    float TextureScale,
    out int2 blendAxes,
    out float4 texA,
    out float4 texB
)
{
    float3 pddx = ddx(PositionWS);
    float3 pddy = ddy(PositionWS);
    
    float3 normal = abs(NormalWS);

    // 最大・最小・中間軸を判定
    int3 max = (normal.x > normal.y && normal.x > normal.z) ? int3(0,1,2) :
               (normal.y > normal.z)                        ? int3(1,2,0) :
                                                              int3(2,0,1);

    int3 min = (normal.x < normal.y && normal.x < normal.z) ? int3(0,1,2) :
               (normal.y < normal.z)                        ? int3(1,2,0) :
                                                              int3(2,0,1);

    int3 med = int3(3,3,3) - max - min;

    // UV展開 (最大軸、次に強い軸)
    float2 uvA    = float2(PositionWS[max.y], PositionWS[max.z]) * TextureScale;
    float2 duvAdx = float2(pddx[max.y], pddx[max.z]) * TextureScale;
    float2 duvAdy = float2(pddy[max.y], pddy[max.z]) * TextureScale;

    float2 uvB    = float2(PositionWS[med.y], PositionWS[med.z]) * TextureScale;
    float2 duvBdx = float2(pddx[med.y], pddx[med.z]) * TextureScale;
    float2 duvBdy = float2(pddy[med.y], pddy[med.z]) * TextureScale;

    blendAxes = int2(max.x, med.x);

    // 2方向からサンプリング
    texA = SAMPLE_TEXTURE2D_GRAD(Texture, Sampler, uvA, duvAdx, duvAdy);
    texB = SAMPLE_TEXTURE2D_GRAD(Texture, Sampler, uvB, duvBdx, duvBdy);
}

// ------------------------------------------------------------
// Bi-Planarマッピング (カラー用)
// アルベド/マスク/任意のテクスチャに対応
void BiPlanarMapping_float(
    float3 PositionWS,
    float3 NormalWS,
    UnityTexture2D Texture,
    UnitySamplerState Sampler,
    float TextureScale,
    float Blend,
    out float4 Out)
{
    int2 blendAxes;
    float4 texA, texB;
    SetupBiPlanarSample(Texture, Sampler, PositionWS, NormalWS, TextureScale, blendAxes, texA, texB);
    
    float2 blendWeight = CalcBlendWeights(abs(NormalWS), blendAxes, Blend);
    Out = (texA * blendWeight.x + texB * blendWeight.y) / (blendWeight.x + blendWeight.y);
}

// ------------------------------------------------------------
// Bi-Planarノーマルマッピング
// ノーマルマップのスケール対応
void BiPlanarNormal_float(
    float3 PositionWS,
    float3 NormalWS,
    UnityTexture2D NormalTex,
    UnitySamplerState Sampler,
    float TextureScale,
    float Blend,
    float NormalScale,
    out float3 Out)
{
    int2 blendAxes;
    float4 texA, texB;
    SetupBiPlanarSample(NormalTex, Sampler, PositionWS, NormalWS, TextureScale, blendAxes, texA, texB);

    float3 tNormalA = UnpackNormalmapRGorAG(texA, NormalScale);
    float3 tNormalB = UnpackNormalmapRGorAG(texB, NormalScale);

    float3 worldNormalA = ReorientToWorld(tNormalA, blendAxes.x, NormalWS);
    float3 worldNormalB = ReorientToWorld(tNormalB, blendAxes.y, NormalWS);

    float2 blendWeight = CalcBlendWeights(abs(NormalWS), blendAxes, Blend);
    Out = normalize(worldNormalA * blendWeight.x + worldNormalB * blendWeight.y);
}
