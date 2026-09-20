"""Copies the shared defaults the Mac app bundles into App/Brochacho/Resources. Run after editing defaults/lines.json."""
import pathlib, shutil
root = pathlib.Path(__file__).resolve().parent.parent
shutil.copyfile(root / 'defaults' / 'lines.json', root / 'App' / 'Brochacho' / 'Resources' / 'lines.json')
print('copied lines.json into the app')
