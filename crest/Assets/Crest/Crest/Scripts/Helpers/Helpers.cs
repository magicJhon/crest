// Crest Ocean System

// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

namespace Crest
{
    using UnityEngine;
    using UnityEngine.Rendering;

    /// <summary>
    /// General purpose helpers which, at the moment, do not warrant a seperate file.
    /// </summary>
    public static class Helpers
    {
        public static bool IsMSAAEnabled(Camera camera)
        {
            return camera.allowMSAA && QualitySettings.antiAliasing > 1;
        }

        public static bool IsMotionVectorsEnabled()
        {
            // Default to false until we support MVs.
            return false;
        }

        public static bool IsIntelGPU()
        {
            // Works for Windows and MacOS. Grabbed from Unity Graphics repository:
            // https://github.com/Unity-Technologies/Graphics/blob/68b0d42c/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs#L198-L199
            return SystemInfo.graphicsDeviceName.ToLowerInvariant().Contains("intel");
        }

        public static void Swap<T>(ref T a, ref T b)
        {
            var temp = b;
            b = a;
            a = temp;
        }
    }

    static class Extensions
    {
        public static void SetKeyword(this Material material, string keyword, bool enabled)
        {
            if (enabled)
            {
                material.EnableKeyword(keyword);
            }
            else
            {
                material.DisableKeyword(keyword);
            }
        }

        public static void SetKeyword(this ComputeShader shader, string keyword, bool enabled)
        {
            if (enabled)
            {
                shader.EnableKeyword(keyword);
            }
            else
            {
                shader.DisableKeyword(keyword);
            }
        }

        public static void SetShaderKeyword(this CommandBuffer buffer, string keyword, bool enabled)
        {
            if (enabled)
            {
                buffer.EnableShaderKeyword(keyword);
            }
            else
            {
                buffer.DisableShaderKeyword(keyword);
            }
        }
    }
}
