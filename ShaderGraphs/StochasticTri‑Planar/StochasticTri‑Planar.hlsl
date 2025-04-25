//────────────────────────────────────────────
//  Stochastic Tri-Planar NormalMap Sampling
//  Based on Shadertoy (https://www.shadertoy.com/view/3lS3Rm)
//────────────────────────────────────────────

inline float hash(float2 p)
{
    return frac(1.0e4 * sin(17.0 * p.x + 0.1 * p.y) * (0.1 + abs(sin(13.0 * p.y + p.x))));
}

inline float hash3D(float3 p)
{
    return hash(float2(hash(p.xy), p.z));
}

void StochasticTriPlanar_float
(
    UnityTexture2D Texture,
    UnitySamplerState Sampler,
    float3 PositionWS,
    float3 NormalWS,
    float TextureScale,
    out float4 Out
)
{
    float3 n = normalize(NormalWS);
    float3 nAbs = abs(n);

    float sqrt3_div3 = 0.57735026919;
    float3 a = max(nAbs - sqrt3_div3, 0.0);
    float3 w = a / max(dot(a, 1.0), 1e-5);

    float3 dx = ddx(n);
    float3 dy = ddy(n);
    float pixDeriv = length(float2(length(dx), length(dy)));
    float pixScale = rcp(pixDeriv + 1e-5);

    float h = hash3D(floor(n * pixScale));

    float2 uv, dudx, dudy;

    if (w.z > h)
    {
        uv   = PositionWS.xy;
        dudx = ddx(PositionWS.xy);
        dudy = ddy(PositionWS.xy);
    }
    else if ((w.z + w.y) > h)
    {
        uv   = PositionWS.xz;
        dudx = ddx(PositionWS.xz);
        dudy = ddy(PositionWS.xz);
    }
    else
    {
        uv   = PositionWS.zy;
        dudx = ddx(PositionWS.zy);
        dudy = ddy(PositionWS.zy);
    }

    uv *= TextureScale;
    dudx *= TextureScale;
    dudy *= TextureScale;

    Out = SAMPLE_TEXTURE2D_GRAD(Texture, Sampler, uv, dudx, dudy);
}