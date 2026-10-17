package com.maizon.megaman8recomp;

import org.libsdl.app.SDLActivity;

/**
 * CI/toolchain smoke-test entry point. The real-runtime build selects the
 * PSXRecomp Android launcher through the manifest placeholder instead.
 */
public final class ShellActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        // SDL3 is statically linked into libmain.so.
        return new String[] { "main" };
    }
}
